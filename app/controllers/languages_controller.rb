class LanguagesController < ApplicationController
  def index
    @languages = Language.all
  end

  def show
    @language = Language.find(params[:id])
    @review = Review.new
  end
end
