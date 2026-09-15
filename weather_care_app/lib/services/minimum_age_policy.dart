const int minimumAgePolicyVersion = 1;

/// Kept temporarily for compatibility with the deployed server contract.
/// The app no longer asks for or stores a user's age.
const Map<String, dynamic> minimumAgeServerAssertion = {
  'minimumAgeConfirmed': true,
  'agePolicyVersion': minimumAgePolicyVersion,
};
