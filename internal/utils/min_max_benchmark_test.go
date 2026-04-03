//go:build go1.24 && !noasm

package utils

import (
	"fmt"
	"math/rand/v2"
	"testing"
	"unsafe"
)

var (
	sinkMinI8  int8
	sinkMaxI8  int8
	sinkMinI32 int32
	sinkMaxI32 int32
	sinkMinI64 int64
	sinkMaxI64 int64
)

func randInt8Slice(n int) []int8 {
	r := rand.New(rand.NewPCG(42, 0))
	s := make([]int8, n)
	for i := range s {
		s[i] = int8(r.Int32())
	}
	return s
}

func randInt32Slice(n int) []int32 {
	r := rand.New(rand.NewPCG(42, 0))
	s := make([]int32, n)
	for i := range s {
		s[i] = r.Int32()
	}
	return s
}

func randInt64Slice(n int) []int64 {
	r := rand.New(rand.NewPCG(42, 0))
	s := make([]int64, n)
	for i := range s {
		s[i] = r.Int64()
	}
	return s
}

func BenchmarkMinMax(b *testing.B) {
	sizes := []int{256, 1024, 8192, 65536}

	b.Run("Int8", func(b *testing.B) {
		for _, n := range sizes {
			data := randInt8Slice(n)
			byteCount := int64(n) * int64(unsafe.Sizeof(int8(0)))

			b.Run(fmt.Sprintf("N=%d", n), func(b *testing.B) {
				b.Run("PureGo", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI8, sinkMaxI8 = int8MinMax(data)
					}
				})
				b.Run("SSE4", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI8, sinkMaxI8 = int8MaxMinSSE4(data)
					}
				})
				b.Run("AVX2", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI8, sinkMaxI8 = int8MaxMinAVX2(data)
					}
				})
				b.Run("AVX512", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI8, sinkMaxI8 = int8MaxMinAVX512(data)
					}
				})
			})
		}
	})

	b.Run("Int32", func(b *testing.B) {
		for _, n := range sizes {
			data := randInt32Slice(n)
			byteCount := int64(n) * int64(unsafe.Sizeof(int32(0)))

			b.Run(fmt.Sprintf("N=%d", n), func(b *testing.B) {
				b.Run("PureGo", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI32, sinkMaxI32 = int32MinMax(data)
					}
				})
				b.Run("SSE4", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI32, sinkMaxI32 = int32MaxMinSSE4(data)
					}
				})
				b.Run("AVX2", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI32, sinkMaxI32 = int32MaxMinAVX2(data)
					}
				})
				b.Run("AVX512", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI32, sinkMaxI32 = int32MaxMinAVX512(data)
					}
				})
			})
		}
	})

	b.Run("Int64", func(b *testing.B) {
		for _, n := range sizes {
			data := randInt64Slice(n)
			byteCount := int64(n) * int64(unsafe.Sizeof(int64(0)))

			b.Run(fmt.Sprintf("N=%d", n), func(b *testing.B) {
				b.Run("PureGo", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI64, sinkMaxI64 = int64MinMax(data)
					}
				})
				b.Run("SSE4", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI64, sinkMaxI64 = int64MaxMinSSE4(data)
					}
				})
				b.Run("AVX2", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI64, sinkMaxI64 = int64MaxMinAVX2(data)
					}
				})
				b.Run("AVX512", func(b *testing.B) {
					b.SetBytes(byteCount)
					for b.Loop() {
						sinkMinI64, sinkMaxI64 = int64MaxMinAVX512(data)
					}
				})
			})
		}
	})
}
