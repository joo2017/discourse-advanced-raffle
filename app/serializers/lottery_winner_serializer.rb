class LotteryWinnerSerializer < ApplicationSerializer
  attributes :id, :draw_time

  has_one :user, serializer: BasicUserSerializer, embed: :objects
  has_one :prize, serializer: LotteryPrizeSerializer, embed: :objects
  
  class WinnerPostSerializer < ApplicationSerializer
    attributes :id, :post_number, :topic_id
  end
  
  has_one :post, serializer: WinnerPostSerializer, embed: :objects
end
