module main

// is_leap_year reports whether a year is a leap year.
fn is_leap_year(year int) bool {
	return if year % 100 == 0 { year % 400 == 0 } else { year % 4 == 0 }
}
