//go:build !noasm

package utils

import (
	"unsafe"
)

//go:noescape
func _int8_max_min_avx512(values unsafe.Pointer, length int, minout, maxout unsafe.Pointer)

func int8MaxMinAVX512(values []int8) (min, max int8) {
	_int8_max_min_avx512(unsafe.Pointer(&values[0]), len(values), unsafe.Pointer(&min), unsafe.Pointer(&max))
	return
}

//go:noescape
func _uint8_max_min_avx512(values unsafe.Pointer, length int, minout, maxout unsafe.Pointer)

func uint8MaxMinAVX512(values []uint8) (min, max uint8) {
	_uint8_max_min_avx512(unsafe.Pointer(&values[0]), len(values), unsafe.Pointer(&min), unsafe.Pointer(&max))
	return
}

//go:noescape
func _int16_max_min_avx512(values unsafe.Pointer, length int, minout, maxout unsafe.Pointer)

func int16MaxMinAVX512(values []int16) (min, max int16) {
	_int16_max_min_avx512(unsafe.Pointer(&values[0]), len(values), unsafe.Pointer(&min), unsafe.Pointer(&max))
	return
}

//go:noescape
func _uint16_max_min_avx512(values unsafe.Pointer, length int, minout, maxout unsafe.Pointer)

func uint16MaxMinAVX512(values []uint16) (min, max uint16) {
	_uint16_max_min_avx512(unsafe.Pointer(&values[0]), len(values), unsafe.Pointer(&min), unsafe.Pointer(&max))
	return
}

//go:noescape
func _int32_max_min_avx512(values unsafe.Pointer, length int, minout, maxout unsafe.Pointer)

func int32MaxMinAVX512(values []int32) (min, max int32) {
	_int32_max_min_avx512(unsafe.Pointer(&values[0]), len(values), unsafe.Pointer(&min), unsafe.Pointer(&max))
	return
}

//go:noescape
func _uint32_max_min_avx512(values unsafe.Pointer, length int, minout, maxout unsafe.Pointer)

func uint32MaxMinAVX512(values []uint32) (min, max uint32) {
	_uint32_max_min_avx512(unsafe.Pointer(&values[0]), len(values), unsafe.Pointer(&min), unsafe.Pointer(&max))
	return
}

//go:noescape
func _int64_max_min_avx512(values unsafe.Pointer, length int, minout, maxout unsafe.Pointer)

func int64MaxMinAVX512(values []int64) (min, max int64) {
	_int64_max_min_avx512(unsafe.Pointer(&values[0]), len(values), unsafe.Pointer(&min), unsafe.Pointer(&max))
	return
}

//go:noescape
func _uint64_max_min_avx512(values unsafe.Pointer, length int, minout, maxout unsafe.Pointer)

func uint64MaxMinAVX512(values []uint64) (min, max uint64) {
	_uint64_max_min_avx512(unsafe.Pointer(&values[0]), len(values), unsafe.Pointer(&min), unsafe.Pointer(&max))
	return
}
