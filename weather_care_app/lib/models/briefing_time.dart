/// A fresh server timeline can begin a few seconds ahead of the device clock.
bool briefingStartsWithinClockSkew(DateTime from, DateTime now) =>
    from.isAfter(now) && from.difference(now) <= const Duration(seconds: 10);
