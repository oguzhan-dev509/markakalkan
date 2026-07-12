enum MarkaKalkanAuthIntent {
  corporateManagement,
  counterfeitTwinReport,
  creationRegistry,
  subscription,
  generalAccount,
}

extension MarkaKalkanAuthIntentX on MarkaKalkanAuthIntent {
  bool get requiresCorporateFlow =>
      this == MarkaKalkanAuthIntent.corporateManagement;
}
