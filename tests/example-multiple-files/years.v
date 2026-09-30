module main

fn is_leap_year(year int) bool {
	if is_century(year) {
		return is_divisible_by(year, 400)
	}
	return is_divisible_by(year, 4)
}
