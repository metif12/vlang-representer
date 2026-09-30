module main

fn is_century(year int) bool {
	return is_divisible_by(year, 100)
}

fn is_divisible_by(year int, by int) bool {
	return year % by == 0
}
