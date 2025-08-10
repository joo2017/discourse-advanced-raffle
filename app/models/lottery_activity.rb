class LotteryActivity < ActiveRecord::Base
  self.table_name = 'lottery_activities'

  belongs_to :topic
  belongs_to :user

  has_many :prizes, class_name: 'LotteryPrize', foreign_key: 'lottery_activity_id', dependent: :destroy
  has_many :winners, class_name: 'LotteryWinner', foreign_key: 'lottery_activity_id', dependent: :destroy

  enum status: { pending: 0, active: 1, finished: 2, cancelled: 3 }
  enum draw_type: { by_time: 0, by_floor: 1, by_manual: 2 }

  validates :topic_id, presence: true, uniqueness: true
  validates :user_id, presence: true
  validates :status, presence: true
  validates :draw_type, presence: true
end
