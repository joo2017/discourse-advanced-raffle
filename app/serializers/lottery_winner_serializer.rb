# app/serializers/lottery_winner_serializer.rb

class LotteryWinnerSerializer < ApplicationSerializer
  # 将 :post 添加到 attributes 列表中
  attributes :id, :draw_time, :post

  # 保留这些 has_one 关联
  has_one :user, serializer: BasicUserSerializer, embed: :objects
  has_one :prize, serializer: LotteryPrizeSerializer, embed: :objects
  
  # 自定义 post 属性的序列化方法
  def post
    # "object" 指向当前的 LotteryWinner 实例
    # 我们安全地调用在模型中定义的 post 方法
    post_model = object.post 
    
    # 如果 post_model 为 nil (例如帖子被永久删除了)，则安全地返回 nil
    # 这是防止程序崩溃的关键！
    return nil unless post_model

    # 如果帖子存在，则手动构建一个安全的 JSON 对象返回
    {
      id: post_model.id,
      post_number: post_model.post_number,
      topic_id: post_model.topic_id
    }
  end
end
