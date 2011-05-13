# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
class StaffsController < ApplicationController
  before_filter :check_authorization!
  before_filter :find_staff, :only => [:show, :edit, :update, :destroy]

  #respond_to :html, :xml, :json
  # GET /staffs
  # GET /staffs.xml
  def index
    @staffs = Staff.org.page(@page)
  end

  # GET /staffs/1
  # GET /staffs/1.xml
  def show
  end

  # GET /staffs/new
  # GET /staffs/new.xml
  def new
    @staff = Staff.new
  end

  # GET /staffs/1/edit
  def edit
  end

  # POST /staffs
  # POST /staffs.xml
  def create
    @staff = Staff.new(params[:staff])
    if @staff.save
      redirect_ajax(@staff)
    else
      render :action => 'new'
    end
  end

  # PUT /staffs/1
  # PUT /staffs/1.xml
  def update
    if @staff.update_attributes(params[:staff])
      redirect_ajax(@staff)
    else
      render :action => 'edit'
    end
  end

  # DELETE /staffs/1
  # DELETE /staffs/1.xml
  def destroy
    @staff.destroy
    redirect_ajax(@staff)
  end

  protected
  def find_staff
    @staff = Staff.org.find(params[:id])
  end
end
