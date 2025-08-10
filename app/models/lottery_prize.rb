class LotteryPrize < ActiveRecord::Base
  self.table_name = 'lottery_prizes'

  belongs_to :lottery_activity, class_name: 'LotteryActivity'

  validates :lottery_activity_id, presence: true
  validates :name, presence: true, length: { maximum: 100 }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
