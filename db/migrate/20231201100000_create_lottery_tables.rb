class CreateLotteryTables < ActiveRecord::Migration[6.1]
  def change
    create_table :lottery_activities do |t|
      t.references :topic, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true

      t.integer :status, null: false, default: 0
      t.integer :draw_type, null: false, default: 0

      t.jsonb :draw_condition, null: false, default: '{}'
      t.jsonb :participation_rules, null: false, default: '{}'

      t.datetime :start_time
      t.datetime :end_time
      t.timestamps
    end

    create_table :lottery_prizes do |t|
      t.references :lottery_activity, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.integer :quantity, null: false, default: 1
      t.string :image_url
      t.timestamps
    end

    create_table :lottery_winners do |t|
      t.references :lottery_activity, null: false, foreign_key: true
      t.references :lottery_prize, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :post_id, null: false

      t.datetime :draw_time, null: false
      t.timestamps
    end

    add_index :lottery_winners, [:lottery_activity_id, :user_id], unique: true, name: 'idx_lottery_winners_on_activity_and_user'
  end
end
