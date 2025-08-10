# app/serializers/lottery_winner_serializer.rb
class LotteryWinnerSerializer < ApplicationSerializer
  attributes :id, :draw_time, :post

  has_one :user, serializer: BasicUserSerializer, embed: :objects
  has_one :prize, serializer: LotteryPrizeSerializer, embed: :objects
  
  def post
    post_model = object.post 
    return nil unless post_model
    {
      id: post_model.id,
      post_number: post_model.post_number,
      topic_id: post_model.topic_id
    }
  end
end
