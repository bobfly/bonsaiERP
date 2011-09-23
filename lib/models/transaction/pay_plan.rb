# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
module Models::Transaction::PayPlan

  MAX_PAY_PLANS_SIZE = 50
  PAY_PLANS_DATE_SEPARATION = 1.month
  DECIMALS = 2

  # Destroys a pay plan
  # @param Array
  def destroy_pay_plans(pp_ids)
    return false unless pp_ids.is_a? Array
    pp_ids.map!(&:to_i)

    pps = unpaid_pay_plans.reverse

    pps.each_with_index do |pp, i|
      if pp_ids.include?(pp.id) and (i + 1) < pps.size
        pp.mark_for_destruction
        @current_pay_plan = pp
      end
    end

    save_pay_plan(true)
  end

  # Sets the amount and the data for last pay_plan
  def new_pay_plan(params = {})
    return false unless credit? # Check credit is approved
    @current_pay_plan = pay_plans.build(params.merge(:ctype => self.class.to_s, :currency_id => currency_id, :transaction_id => id))
  end

  # Updates one of the pay_plans
  def edit_pay_plan(pp_id, params = {})
    @current_pay_plan = pay_plans.select {|pp| pp.id == pp_id.to_i }.first
    return false if @current_pay_plan.paid?
    @current_pay_plan.attributes = params
    @current_pay_plan
  end

  def save_pay_plan(dest = false)
    return false unless @current_pay_plan.valid?
    # Eliminate if there is other pay plan with the same date
    unpaid_pay_plans.each do |pp|
      if  pp.payment_date == @current_pay_plan.payment_date and not(@current_pay_plan == pp)
        pp.mark_for_destruction
      end
    end

    create_pattern if @current_pay_plan.repeat?
    pps = sort_pay_plans
    
    bal = balance

    pps.each do |pp|
      if pp.amount > bal and bal > 0
        pp.amount = bal
        bal = 0
      elsif bal == 0
        # Eliminate all other pay_plans that exeed the amount
        pp.mark_for_destruction
      else
        bal -= pp.amount
      end
    end
    
    complete_pay_plan(pps.last, bal, dest) if bal > 0
    self.payment_date = pps.first.payment_date

    self.save
  end

  private
    # Creates a repeating pattern using the @current_pay_plan as base
    def create_pattern
      pps = sort_pay_plans
      bal = balance

      amt = pps.inject(0) do |sum, pp|
        sum += pp.amount if pp.payment_date < @current_pay_plan.payment_date
        sum
      end

      # Marks which pay_plans to destroy
      destroy_pay_plans_pattern(pps)

      bal    -= amt
      pdate   = @current_pay_plan.payment_date

      while bal > 0
        # set the amount
        amt = (bal - @current_pay_plan.amount > 0) ? @current_pay_plan.amount : bal
        adate = pdate - 5.days

        pay_plans.build(
          :payment_date => pdate, 
          :alert_date => adate, 
          :amount => amt,
          :email => @current_pay_plan.email,
          :currency_id => currency_id
        )

        pdate += PAY_PLANS_DATE_SEPARATION
        bal -= amt
      end
    end

    # Completes the pay_plans to reach the balance
    def complete_pay_plan(pp, bal, dest)
      if dest
        pps = sort_pay_plans.last
        pp.amount += bal
      else
        pay_plans.build(
          :payment_date => pp.payment_date + PAY_PLANS_DATE_SEPARATION, 
          :alert_date => pp.payment_date - 5.days, 
          :amount => bal,
          :email => @current_pay_plan.email,
          :currency_id => currency_id
        )
      end
    end

    #def calculate_int_percentage(pp, bal)
    #  return 0 if bal <= 0
    #  pp.interests_penalties / bal
    #end

    # Marks the pay_plans for destruction if payment_date is <= than @current_pay_plan
    def destroy_pay_plans_pattern(pps)
      pps.each do |pp|
        pp.mark_for_destruction if @current_pay_plan.payment_date <= pp.payment_date 
      end
    end

    # sorts all active pay plans
    def sort_pay_plans
      unpaid_pay_plans.sort {|a, b| a.payment_date <=> b.payment_date }
    end

    def unpaid_pay_plans
      pay_plans.select {|pp| pp.paid == false and not(pp.marked_for_destruction?) }
    end

end
