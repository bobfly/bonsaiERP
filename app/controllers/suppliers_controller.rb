# encoding: utf-8
# author: Boris Barroso
# email: boriscyber@gmail.com
class SuppliersController < ApplicationController
  before_filter :find_supplier, :only => [:show, :edit, :update, :destroy]

  #respond_to :html, :xml, :json
  # GET /suppliers
  # GET /suppliers.xml
  def index
    @suppliers = Supplier.org.page(@page)
  end

  # GET /suppliers/1
  # GET /suppliers/1.xml
  def show
  end

  # GET /suppliers/new
  # GET /suppliers/new.xml
  def new
    @supplier = Supplier.new
  end

  # GET /suppliers/1/edit
  def edit
  end

  # POST /suppliers
  # POST /suppliers.xml
  def create
    @supplier = Supplier.new(params[:supplier])
    if @supplier.save
      redirect_ajax(@supplier)
    else
      render :action => 'new'
    end
  end

  # PUT /suppliers/1
  # PUT /suppliers/1.xml
  def update
    if @supplier.update_attributes(params[:supplier])
      redirect_ajax(@supplier)
    else
      render :action => 'edit'
    end
  end

  # DELETE /suppliers/1
  # DELETE /suppliers/1.xml
  def destroy
    @supplier.destroy
    respond_ajax(@supplier)
  end

  protected
  def find_supplier
    @supplier = Supplier.org.find(params[:id])
  end
end

