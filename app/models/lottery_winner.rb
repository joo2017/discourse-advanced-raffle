class LotteryWinner < ActiveRecord::Base
  self.table_name = 'lottery_winners'

  belongs_to :lottery_activity, class_name: 'LotteryActivity'
  belongs_to :lottery_prize, class_name: 'LotteryPrize'
  belongs_to :user

  def post
    Post.find_by(id: self.post_id)
  end

  validates :lottery_activity_id, presence: true
  validates :lottery_prize_id, presence: true
  validates :user_id, presence: true
  validates :post_id, presence: true
end
