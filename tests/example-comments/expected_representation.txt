module main

// Check the Gregorian rule: divisible by 4, except centuries, except 400s.
fn is_leap_year(year int) bool {
	// the century case is the fiddly one
	if year % 100 == 0 {
		return year % 400 == 0
	}
	return year % 4 == 0
}
