# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
require File.dirname(__FILE__) + '/acceptance_helper'

#expect { t2.save }.to raise_error(ActiveRecord::StaleObjectError)

feature "Buy", "test features" do

  background do
    create_organisation_session
    create_user_session
  end

  let(:pay_plan_params) do
    d = options[:payment_date] || Date.today
    {:alert_date => (d - 5.days), :payment_date => d,
     :interests_penalties => 0,
     :ctype => 'Buy', :description => 'Prueba de vida!', 
     :email => true }.merge(options)
  end

  let!(:organisation) { create_organisation(:id => 1) }
  let!(:items) { create_items }
  let!(:bank) { create_bank(:number => '123', :amount => 0) }
  let(:bank_account) { bank.account }
  let!(:supplier) { create_supplier(:matchcode => 'Manuel Morales') }
  let!(:client) { create_client(:matchcode => "Karina Luna")}
  let(:buy_params) do
      d = Date.today
      buy_params = {"active"=>nil, "bill_number"=>"56498797", "contact_id"=> supplier.id, 
        "exchange_rate"=>1, "currency_id"=>1, "date"=> d, 
        "description"=>"Esto es una prueba", "discount" => 3, "project_id"=>1 
      }
      details = [
        { "description"=>"jejeje", "item_id"=>1, "organisation_id"=>1, "price"=>3, "quantity"=> 10},
        { "description"=>"jejeje", "item_id"=>2, "organisation_id"=>1, "price"=>5, "quantity"=> 20}
      ]
      buy_params[:transaction_details_attributes] = details
      buy_params
  end

  scenario "Create a buy" do

    log.info "Creating new buy"
    b = Buy.new(buy_params)

    b.should be_cash
    b.save_trans.should be(true)
    b.should be_draft

    b.reload
    log.info "Checking details, cash and balance for buy"
    b.transaction_details.size.should == 2
    b.should be_cash
    tot = ( 3 * 10 + 5 * 20 )
    b.total.should == tot.round(2)
    b.balance.should == b.total
    b.total_currency.should == b.total
    b.should be_draft

    log.info "Checking buy details"
    b.transaction_details[0].balance.should == 10
    b.transaction_details[0].original_price.should == 3
    b.transaction_details[1].balance.should == 20
    b.transaction_details[1].original_price.should == 5

    b.approve!.should == true
    b.reload
    b.approver_id.should == 1
    b.state.should == "approved"

    # Create a payment
    b.payment?.should == false

    p = b.new_payment(:account_id => bank_account.id, :base_amount => 30, :exchange_rate => 1, :reference => 'Cheque 143234')
    p.class.should == AccountLedger
    p.payment?.should == true
    p.operation.should == 'out'
    p.amount.should == 30
    p.interests_penalties.should == 0

    b.save_payment.should be_false
    #b.payment?.should == false
    p.errors[:amount].should_not be_blank

    # Must reload so it sets again to the original values balance
    b.reload
    # Make an in in the bank to verify
    al = AccountLedger.new_money(:operation => "in", :account_id => bank_account.id, :contact_id => client.id, :amount => 500, :reference => "Check 1120012" )

    al.save.should be_true
    al.conciliate_account.should be_true

    bank_account.reload
    bank_account.amount.should == 500

    bal = b.balance
    p = b.new_payment(:account_id => bank_account.id, :base_amount => 30, :exchange_rate => 1, :reference => 'Cheque 143234')

    b.save_payment.should be_true
    p.should be_persisted

    p.to_id.should == Account.org.find_by_original_type(b.class.to_s).id
    p.description.should_not == blank?
    p.amount.should == -30

    b.reload
    b.balance.should == bal - 30

    p.should_not be_conciliation

    p.conciliate_account.should be_true

    p.approver_id.should == UserSession.user_id
    p.approver_datetime.kind_of?(Time).should == true

    bank_account.reload
    bank_account.amount.should == 500 - 30

    b.deliver.should == false
    b.reload
    
    p = b.new_payment(:account_id => bank_account.id, :base_amount => b.balance, :reference => 'Cheque 222289', :exchange_rate => 1)

    b.save_payment.should be_true
    b.reload

    p.conciliation.should == false
    b.state.should == 'paid'
    b.deliver.should == false

    # Conciliation
    p.conciliate_account.should be_true
    p.reload
  
    b.reload

    p.conciliation.should be_true
    b.reload
    b.balance.should == 0
    p.conciliation.should be_true
    
  end

  scenario "Pay with staff account" do
    st = create_staff(:matchcode => "Debere pagar", :position => "Ugier")
    st.should be_persisted
    st_account = st.accounts.first
    st.accounts.first.amount.should == 0

    al = AccountLedger.new_money(:operation => "in", :account_id => bank_account.id, :contact_id => client.id, :amount => 500, :reference => "Check 1120012" )

    al.save.should be_true
    al.conciliate_account.should be_true

    bank_account.reload
    bank_account.amount.should == 500

    al = AccountLedger.new_money(:operation => "out", :account_id => bank_account.id, :contact_id => st.id, :amount => 100, :reference => "Check 1120012" )

    al.save.should be_true
    al.conciliate_account.should be_true

    bank_account.reload
    bank_account.amount.should == 400

    st_account.reload
    st_account.amount.should == 100

    # Buy
    b = Buy.new(buy_params)

    b.should be_cash
    b.save_trans.should be(true)
    b.should be_draft

    b.save_trans.should be_true
    b.balance.should == 130

    b.approve!.should be_true

    p = b.new_payment(:account_id => st_account.id, :base_amount => b.balance, :reference => 'Cheque 222289', :exchange_rate => 1)
    p.class.should == AccountLedger

    b.save_payment.should be_false
    p.errors[:amount].should_not be_blank
    p.errors[:base_amount].should_not be_blank


    al = AccountLedger.new_money(:operation => "out", :account_id => bank_account.id, :contact_id => st.id, :amount => 100, :reference => "Check 1120012" )

    al.save.should be_true
    al.conciliate_account.should be_true

    bank_account.reload
    bank_account.amount.should == 300

    st_account.reload
    st_account.amount.should == 200

    b.reload

    p = b.new_payment(:account_id => st_account.id, :amount => b.balance, :reference => 'Cheque 222289', :exchange_rate => 1)

    b.save_payment.should be_true
    p.should be_persisted
    p.staff_id.should == st.id

    p.conciliate_account.should be_true
    st_account.reload
    st_account.amount.should == 70
  end


end
