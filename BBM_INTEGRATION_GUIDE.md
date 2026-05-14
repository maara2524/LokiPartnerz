# BBM Integration Guide for Flutter App

## Overview
Your Flutter lead management app has been successfully integrated with the existing BBM (BridalBooker Machine) system. This guide explains the integration and deployment steps.

## Integration Changes Made

### 1. API Configuration Updated
- **File**: `lib/config/api_config.dart`
- **Changes**: Updated to use BBM's existing API endpoints
- **Endpoints**:
  - Login: `/login`
  - Available Leads: `/artist/api/available-leads`
  - Claim Stats: `/artist/api/claim-stats`
  - Claim Lead: `/artist/claim-lead`
  - Release Lead: `/artist/release-lead`

### 2. Authentication System
- **File**: `lib/login_page.dart`
- **Changes**: Modified to work with BBM's form-based authentication
- **Format**: Uses `application/x-www-form-urlencoded` instead of JSON

### 3. Data Models Updated
- **File**: `lib/available_leads_page.dart`
- **Changes**: Added `fromBBMJson` method to handle BBM's data structure
- **Fields**: Maps BBM fields (`customer_name`, `event_date`, etc.) to Flutter models

### 4. API Calls Modified
All API calls now use:
- Form data format instead of JSON
- BBM's specific response structure
- Proper error handling for BBM responses

## Deployment Steps

### Step 1: Update Base URL
In `lib/config/api_config.dart`, replace:
```dart
static const String baseUrl = "https://yourdomain.com";
```
With your actual BBM deployment URL.

### Step 2: Test Locally (Optional)
If you have local BBM setup:
```dart
static const String baseUrl = "http://localhost/BBM";
```

### Step 3: Build Flutter App
```bash
flutter clean
flutter pub get
flutter build apk --release  # For Android
flutter build ios --release  # For iOS
```

## BBM System Requirements

### Database Tables Used
- `users` - User authentication and profiles
- `artist_profiles` - Artist business information
- `leads` - Lead data with claim system
- `lead_assignments` - Lead assignment history

### Required BBM Features
- Claim/lock system with expiry management
- Artist role-based access
- API endpoints for mobile integration

## API Response Formats

### Available Leads Response
```json
{
  "leads": [
    {
      "id": 1,
      "customer_name": "Customer Name",
      "location": "City",
      "event_date": "2025-10-15",
      "event_type": "Wedding",
      "status": "new",
      "budget_range": "₹15,000 - ₹25,000"
    }
  ]
}
```

### Claim Stats Response
```json
{
  "total_claims": 5,
  "new_claims": 2,
  "contacted_claims": 2,
  "booked_claims": 1,
  "claimed_leads": [...],
  "recent_leads": [...]
}
```

## Testing Checklist

- [ ] Login with BBM credentials works
- [ ] Available leads display correctly
- [ ] Lead claiming functionality works
- [ ] Dashboard shows correct statistics
- [ ] My claims page shows claimed leads
- [ ] Lead release functionality works
- [ ] All API calls use correct format

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Ensure BBM system has CORS headers enabled
   - Check if mobile app domain is whitelisted

2. **Authentication Issues**
   - Verify BBM login credentials
   - Check session management in BBM system

3. **API Format Errors**
   - Ensure using form data, not JSON
   - Verify field names match BBM expectations

4. **Data Display Issues**
   - Check BBM response structure
   - Verify field mappings in Flutter models

## Next Steps

1. Deploy BBM system to production server
2. Update Flutter app with production URL
3. Test complete integration flow
4. Deploy Flutter app to app stores
5. Monitor API usage and performance

## Support

For BBM system issues, contact the BBM developer.
For Flutter app issues, refer to this integration guide.
