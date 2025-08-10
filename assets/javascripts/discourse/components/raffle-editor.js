import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Component.extend({
  modal: service(),
  
  didInsertElement() {
    this._super(...arguments);
    const activity = this.model.topic.lottery_activity;
    
    if (activity) {
      this.setProperties({
        status: activity.status,
        drawType: activity.draw_type,
        endTime: activity.end_time,
        drawConditionFloor: activity.draw_condition.floor,
        rulesKeyword: activity.participation_rules.keyword,
        rulesMinLevel: activity.participation_rules.min_level,
        rulesUniqueUser: activity.participation_rules.unique_user,
        prizes: activity.prizes.map(p => ({...p})),
      });
    } else {
      this.setProperties({
        status: "active",
        drawType: "by_time",
        endTime: null,
        drawConditionFloor: 100,
        rulesKeyword: "",
        rulesMinLevel: 0,
        rulesUniqueUser: true,
        prizes: [{ name: "一等奖", quantity: 1, description: "" }],
      });
    }
  },
  
  @action
  addPrize() {
    this.prizes.pushObject({ name: "新奖品", quantity: 1, description: "" });
  },

  @action
  removePrize(prize) {
    this.prizes.removeObject(prize);
  },

  @action
  saveRaffle() {
    this.set("isLoading", true);

    const data = {
      activity: {
        status: this.status,
        draw_type: this.drawType,
        end_time: this.drawType === 'by_time' ? this.endTime : null,
        draw_condition: {
          floor: this.drawType === 'by_floor' ? this.drawConditionFloor : null,
        },
        participation_rules: {
          keyword: this.rulesKeyword,
          min_level: this.rulesMinLevel,
          unique_user: this.rulesUniqueUser,
        },
        prizes: this.prizes,
      }
    };
    
    ajax(`/raffles/${this.model.topic.id}`, {
      data: JSON.stringify(data),
      contentType: "application/json",
      type: "PUT",
    })
      .then((updatedActivity) => {
        this.model.topic.set("lottery_activity", updatedActivity);
        this.modal.close();
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.set("isLoading", false);
      });
  },
});
