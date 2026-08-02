// https://bbm.lokiwebvibe.com/mobile_api/subscriptions/razorpay_webhook.php

class ApiConfig {

  static const String baseUrl = "https://bbm.lokiwebvibe.com"; 
  static const String privacyPolicyUrl = "$baseUrl/privacy.html";

  static const String loginEndpoint = "$baseUrl/mobile_api/auth.php";
  static const String uiConfigEndpoint = "$baseUrl/mobile_api/get_ui_config.php";
  static const String getSubscriptionPlansEndpoint = "$baseUrl/mobile_api/subscriptions/get_subscription_plans.php";
  static const String confirmRazorpayPaymentEndpoint = "$baseUrl/mobile_api/subscriptions/confirm_razorpay_payment.php";
  static const String createRazorpayOrderEndpoint = "$baseUrl/mobile_api/subscriptions/create_order.php";
  static const String callbackEndpoint = "$baseUrl/mobile_api/payment_callback.php";
  static const String tutorialVideosEndpoint = "$baseUrl/mobile_api/tutorial_videos.php";
  static const String subscriptionIntroVideoEndpoint = "$baseUrl/mobile_api/subscription-intro-video.php";
  static const String registerEndpoint = "$baseUrl/mobile_api/register.php";
  static const String deleteAccountEndpoint = "$baseUrl/mobile_api/delete_account.php";
  static const String availableLeadsEndpoint = "$baseUrl/mobile_api/all_leads.php";
  static const String claimStatsEndpoint = "$baseUrl/mobile_api/stats.php";
  static const String claimLeadEndpoint = "$baseUrl/mobile_api/claim_leads.php";
  static const String releaseLeadEndpoint = "$baseUrl/mobile_api/release.php";
  static const String updateStatusEndpoint = "$baseUrl/mobile_api/update_status.php";
  static const String getArtistProfileEndpoint = "$baseUrl/mobile_api/get_profile.php";
  static const String updateArtistProfileEndpoint = "$baseUrl/mobile_api/update_artist_profile.php";  
  static const String leadDetailsEndpoint = "$baseUrl/mobile_api/lead_details.php";
  static const String saveFCMTokenEndpoint = "$baseUrl/mobile_api/save_fcm_token.php";
  static const String addNewNoteEndpoint = "$baseUrl/mobile_api/add_new_note.php";
  static const String getFollowupStatusEndpoint = "$baseUrl/mobile_api/get_followup_status.php";
  static const String versionCheckEndpoint = "$baseUrl/mobile_api/check_app_version.php";
  static const String telecallerDashboardEndpoint = "$baseUrl/mobile_api/telecaller_dashboard.php";
  static const String telecallerMyLeadsEndpoint = "$baseUrl/mobile_api/telecaller_my_leads.php";
  static const String telecallerReportEndpoint = "$baseUrl/mobile_api/telecaller_report.php";
  static const String eliteArtistsEndpoint = "$baseUrl/mobile_api/elite_artists.php";
  static const String assignArtistEndpoint = "$baseUrl/mobile_api/assign_artist.php";
  static const String sendOtpEndpoint = "$baseUrl/mobile_api/password_recovery/send_otp.php";
  static const String verifyOtpEndpoint = "$baseUrl/mobile_api/password_recovery/verify_otp.php";
  static const String resetPasswordEndpoint = "$baseUrl/mobile_api/password_recovery/reset_password.php";

  static const String adminDashboardEndpoint = "$baseUrl/mobile_api/admin/dashboard.php";
  static const String adminUsersEndpoint = "$baseUrl/mobile_api/admin/users.php";
  static const String adminUserCreateEndpoint = "$baseUrl/mobile_api/admin/user_create.php";
  static const String adminUserUpdateEndpoint = "$baseUrl/mobile_api/admin/user_update.php";
  static const String adminUserToggleStatusEndpoint = "$baseUrl/mobile_api/admin/user_toggle_status.php";
  static const String adminUserDeleteEndpoint = "$baseUrl/mobile_api/admin/user_delete.php";
  static const String adminUserGrantPlanEndpoint = "$baseUrl/mobile_api/admin/user_grant_plan.php";
  static const String adminUserClaimLimitUpdateEndpoint = "$baseUrl/mobile_api/admin/user_claim_limit_update.php";
  static const String adminLeadsEndpoint = "$baseUrl/mobile_api/admin/leads.php";
  static const String adminLeadDetailEndpoint = "$baseUrl/mobile_api/admin/lead_detail.php";
  static const String adminLeadUpdateEndpoint = "$baseUrl/mobile_api/admin/lead_update.php";
  static const String adminLeadUnlockEndpoint = "$baseUrl/mobile_api/admin/lead_unlock.php";
  static const String adminLeadDeleteEndpoint = "$baseUrl/mobile_api/admin/lead_delete.php";
  static const String adminReleaseAllLeadsEndpoint = "$baseUrl/mobile_api/admin/leads_release_all.php";
  static const String adminSubscriptionsEndpoint = "$baseUrl/mobile_api/admin/subscriptions.php";
  static const String adminSubscriptionPlanUpdateEndpoint = "$baseUrl/mobile_api/admin/subscription_plan_update.php";
  static const String adminSettingsEndpoint = "$baseUrl/mobile_api/admin/settings.php";
  static const String adminSettingsUpdateVersionEndpoint = "$baseUrl/mobile_api/admin/settings_update_version.php";
  static const String adminSettingsUpdateTogglesEndpoint = "$baseUrl/mobile_api/admin/settings_update_toggles.php";
  static const String adminSettingsUpdateUiConfigEndpoint = "$baseUrl/mobile_api/admin/settings_update_ui_config.php";
  static const String adminTelecallerCreateEndpoint = "$baseUrl/mobile_api/admin/telecaller_create.php";
  static const String adminTelecallerRemoveEndpoint = "$baseUrl/mobile_api/admin/telecaller_remove.php";
}
