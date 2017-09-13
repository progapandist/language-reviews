class ReviewsController < ApplicationController
  def create
    @review = Review.new(review_params)
    @language = Language.find(params[:language_id])
    @review.language = @language
    if @review.save
      redirect_to @review.language
    else
      render 'languages/show'
    end
  end

  def destroy
    @review = Review.find(params[:id])
    @review.destroy
    redirect_to @review.language
  end

  private

  def review_params
    params.require(:review).permit(:content)
  end
end
