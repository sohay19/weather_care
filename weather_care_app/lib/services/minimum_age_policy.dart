const int minimumServiceAge = 14;
const int minimumAgePolicyVersion = 1;

/// Sent only from the app path that has already passed the local 14+ gate.
/// The server requires this assertion so legacy clients cannot keep an old
/// notification registration active without adopting the current policy.
const Map<String, dynamic> minimumAgeServerAssertion = {
  'minimumAgeConfirmed': true,
  'agePolicyVersion': minimumAgePolicyVersion,
};
