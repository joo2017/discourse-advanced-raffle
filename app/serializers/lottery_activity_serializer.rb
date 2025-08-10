class LotteryActivitySerializer < ApplicationSerializer
  attributes :id, :status, :draw_type, :start_time, :end_time, :draw_condition, :participation_rules
  
  has_many :prizes, serializer: LotteryPrizeSerializer, embed: :objects
  has_many :winners, serializer: LotteryWinnerSerializer, embed: :objects

  def include_winners?
    object.status == 'finished'
  end
end
