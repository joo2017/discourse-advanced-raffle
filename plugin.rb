# name: discourse-advanced-raffle
# about: A plugin to create advanced raffles/lotteries in Discourse topics.
# version: 0.1
# authors: Your Name / Company
# url: https://github.com/your-repo/discourse-advanced-raffle

enabled_site_setting :raffle_enabled

# 在新版 Discourse 中，assets 目录下的 JS 和 SCSS 文件会被自动加载
# 无需手动调用 register_asset

after_initialize do
  # 依赖 Discourse 的 autoloading 机制加载 app 和 lib 目录下的文件

  Topic.class_eval do
    has_one :lottery_activity, class_name: "LotteryActivity", dependent: :destroy
  end

  module ::DiscourseAdvancedRaffle
    class RafflesController < ::ApplicationController
      requires_plugin 'discourse-advanced-raffle'
      before_action :ensure_logged_in

      def update
        topic = Topic.find_by(id: params[:topic_id])
        return render_json_error(I18n.t('topic.not_found'), status: 404) unless topic
        guardian.ensure_can_edit!(topic)

        activity = LotteryActivity.find_or_initialize_by(topic_id: topic.id)
        activity.user_id = current_user.id

        activity_params = params.require(:activity).permit(
          :status,
          :draw_type,
          :start_time,
          :end_time,
          draw_condition: {},
          participation_rules: {}
        )
        
        prizes_params = params.require(:activity).permit(prizes: [:id, :name, :description, :quantity, :image_url])[:prizes] || []

        ActiveRecord::Base.transaction do
          activity.assign_attributes(activity_params)
          activity.save!

          activity.prizes.destroy_all
          activity.prizes.create!(prizes_params) if prizes_params.present?
        end

        render json: LotteryActivitySerializer.new(activity, root: false).as_json
      rescue ActiveRecord::RecordInvalid => e
        render_json_error(e.message, status: 422)
      end
    end

    class Engine < ::Rails::Engine
      engine_name 'discourse_advanced_raffle'
      isolate_namespace DiscourseAdvancedRaffle
    end

    Engine.routes.draw do
      put '/:topic_id' => 'raffles#update'
    end
  end

  Discourse::Application.routes.append do
    mount DiscourseAdvancedRaffle::Engine, at: '/raffles'
  end

  require_dependency "topic_view_serializer"
  add_to_serializer(:topic_view, :lottery_activity, false) do
    # 确保 object.topic 存在
    object.topic&.lottery_activity ? LotteryActivitySerializer.new(object.topic.lottery_activity, root: false).as_json : nil
  end

  add_to_serializer(:topic_view, :include_lottery_activity?) do
    # 确保 object.topic 存在
    object.topic&.lottery_activity.present?
  end
end
