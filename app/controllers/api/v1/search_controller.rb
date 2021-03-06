require 'ebay'
require 'amazon'

class Api::V1::SearchController < ApplicationController
  protect_from_forgery unless: -> { request.format.json? }
  
  def create
    @amazon_failed = false
    @search_term = search_params[:search]

    # time_one = Time.new

    amazon_search = Amazon.new
    amazon_response = amazon_search.fetch(@search_term)

    @amazon_response_detail = {}
    if amazon_response
      @amazon_response_detail = amazon_response.first

      amazon_detail_price = 0
      if @amazon_response_detail["ItemAttributes"]["ListPrice"]
        amazon_detail_price = @amazon_response_detail["ItemAttributes"]["ListPrice"]["Amount"].to_f / 100
      elsif @amazon_response_detail["OfferSummary"]
        amazon_detail_price = @amazon_response_detail["OfferSummary"]["LowestNewPrice"]["Amount"].to_f / 100
      end

      amazon_response_similar_all = amazon_response.drop(1)
      @amazon_response_similar = amazon_response_similar_all.shift(9)

      amazon_response_related = amazon_search.related_items(@amazon_response_detail["ASIN"])

      if amazon_response_related != nil
        @amazon_response_similar.concat(amazon_response_related)
      end
    else
      puts "amazon search failed"
      @amazon_failed = true
    end

    @ebay_failed = false
    ebay_search= Ebay.new
    ebay_response = ebay_search.fetchCurrent(
      @search_term, 
      "BestMatch", 
      50, 
      1
      )

    if ebay_response
      @ebay_response_detail = ebay_response.first
      @ebay_response_active = ebay_response.drop(1)
      @ebay_response_active.pop(@ebay_response_active.length - @amazon_response_similar.length)

      ebay_completed_search = Ebay.new
      @ebay_response_completed = ebay_completed_search.fetchCompleted(@search_term)
      @ebay_response_completed.pop(@ebay_response_completed.length - @amazon_response_similar.length)
      @ebay_avg = @ebay_response_completed.first["priceAvgHuman"]
      ebay_avg_decimal = @ebay_response_completed.first["priceAvgDecimal"]
    else
      puts 'ebay search failed'
      @ebay_failed = true
    end

    
    
    render json: {
      amazon_failed: @amazon_failed,
      ebay_failed: @ebay_failed,
      search_term: @search_term, 
      amazon_detail: @amazon_response_detail, 
      amazon_similar: @amazon_response_similar,
      ebay_detail: @ebay_response_detail,
      ebay_active: @ebay_response_active,
      ebay_completed: @ebay_response_completed,
      ebay_avg: @ebay_avg,
      ebay_avg_discount: @ebay_avg_discount_human
    }
  end

  private
  def search_params
    params.require(:searchTerm).permit(
      :search
    )
  end
end