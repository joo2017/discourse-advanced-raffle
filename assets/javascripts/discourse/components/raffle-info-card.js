import Component from "@ember/component";
import { computed } from "@ember/object";
import I18n from "I18n";

export default Component.extend({
  tagName: "",

  isFinished: computed("activity.status", function () {
    return this.activity.status === "finished";
  }),

  drawTypeText: computed("activity.draw_type", function () {
    return I18n.t(`raffle.modal.types.${this.activity.draw_type}`);
  }),

  conditionText: computed(
    "activity.draw_type",
    "activity.end_time",
    "activity.draw_condition.floor",
    function () {
      if (this.activity.draw_type === "by_time") {
        return I18n.t("raffle.card.ends_at", {
          date: moment(this.activity.end_time).format("YYYY-MM-DD HH:mm"),
        });
      }
      if (this.activity.draw_type === "by_floor") {
        return I18n.t("raffle.card.ends_at_floor", {
          floor: this.activity.draw_condition.floor,
        });
      }
      return "";
    }
  ),
});
