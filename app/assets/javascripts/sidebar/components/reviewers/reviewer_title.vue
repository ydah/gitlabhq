<script>
// NOTE! For the first iteration, we are simply copying the implementation of Assignees
// It will soon be overhauled in Issue https://gitlab.com/gitlab-org/gitlab/-/issues/233736
import { GlLoadingIcon } from '@gitlab/ui';
import { n__ } from '~/locale';

export default {
  name: 'ReviewerTitle',
  components: {
    GlLoadingIcon,
  },
  props: {
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    numberOfReviewers: {
      type: Number,
      required: true,
    },
    editable: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    reviewerTitle() {
      const reviewers = this.numberOfReviewers;
      return n__('Reviewer', `%d Reviewers`, reviewers);
    },
  },
};
</script>
<template>
  <div class="hide-collapsed gl-line-height-20 gl-mb-2 gl-text-gray-900 gl-font-weight-bold">
    {{ reviewerTitle }}
    <gl-loading-icon v-if="loading" size="sm" inline class="align-bottom" />
    <a
      v-if="editable"
      class="js-sidebar-dropdown-toggle edit-link btn gl-text-gray-900! gl-ml-auto hide-collapsed btn-default btn-sm gl-button btn-default-tertiary gl-float-right"
      href="#"
      data-track-action="click_edit_button"
      data-track-label="right_sidebar"
      data-track-property="reviewer"
      data-testid="reviewers-edit-button"
    >
      {{ __('Edit') }}
    </a>
  </div>
</template>
