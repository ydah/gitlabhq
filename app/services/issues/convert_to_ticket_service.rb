# frozen_string_literal: true

module Issues
  class ConvertToTicketService < ::BaseContainerService
    def initialize(target:, current_user:, email:)
      super(container: target.resource_parent, current_user: current_user)

      @target = target
      @email = email
      @original_author = target.author
    end

    def execute
      return error_feature_flag unless Feature.enabled?(:convert_to_ticket_quick_action, target.project, type: :beta)
      return error_underprivileged unless current_user.can?(:"admin_#{target.to_ability_name}", target)
      return error_already_ticket if ticket?
      return error_invalid_email unless valid_email?

      update_target
      add_note

      ServiceResponse.success(message: success_message)
    end

    private

    attr_reader :target, :email, :original_author

    def update_target
      target.update!(
        service_desk_reply_to: email,
        author: Users::Internal.support_bot,
        confidential: true
      )

      # Migrate to IssueEmailParticipants::CreateService
      # once :issue_email_participants feature flag has been removed
      # https://gitlab.com/gitlab-org/gitlab/-/issues/440456
      IssueEmailParticipant.create!(issue: target, email: email)
    end

    def add_note
      message = s_(
        "ServiceDesk|This issue has been converted to a Service Desk ticket. " \
        "The email address `%{email}` is the new author of this issue. " \
        "GitLab didn't send a `thank_you` Service Desk email. " \
        "The original author of this issue was `%{original_author}`."
      )

      ::Notes::CreateService.new(
        project,
        Users::Internal.support_bot,
        noteable: target,
        note: format(message, email: email, original_author: original_author.to_reference),
        internal: true
      ).execute
    end

    def ticket?
      target.from_service_desk?
    end

    def valid_email?
      email.present? && IssueEmailParticipant.new(issue: target, email: email).valid?
    end

    def error(message)
      ServiceResponse.error(message: message)
    end

    def error_feature_flag
      # Don't translate feature flag error because it's temporary.
      error("Feature flag convert_to_ticket_quick_action is not enabled for this project.")
    end

    def error_underprivileged
      error(_("You don't have permission to manage this issue."))
    end

    def error_already_ticket
      error(s_("ServiceDesk|Cannot convert to ticket because it is already a ticket."))
    end

    def error_invalid_email
      error(
        s_("ServiceDesk|Cannot convert issue to ticket because no email was provided or the format was invalid.")
      )
    end

    def success_message
      s_('ServiceDesk|Converted issue to Service Desk ticket.')
    end
  end
end
