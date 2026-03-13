// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package metadata

import (
	"math/rand/v2"
	"testing"

	"github.com/apache/arrow-go/v18/arrow/bitutil"
	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/apache/arrow-go/v18/parquet"
)

// BenchmarkBloomFilterInsertSpaced benchmarks inserting spaced values into bloom filter
func BenchmarkBloomFilterInsertSpaced(b *testing.B) {
	sizes := []int{100, 1000, 10000}
	sparsities := []float64{0.5, 0.75, 0.9} // fraction of valid bits

	for _, size := range sizes {
		for _, sparsity := range sparsities {
			b.Run(formatBenchName(size, sparsity), func(b *testing.B) {
				mem := memory.DefaultAllocator
				bf := NewBloomFilter(1024, maximumBloomFilterBytes, mem)
				h := bf.Hasher()

				// Create test data with specified sparsity
				vals := make([]int32, size)
				validBits := make([]byte, bitutil.BytesForBits(int64(size)))
				numValid := int(float64(size) * sparsity)

				r := rand.New(rand.NewPCG(42, 42))
				for i := range vals {
					vals[i] = r.Int32()
				}

				// Set validBits to achieve desired sparsity
				validIdx := 0
				for validIdx < numValid {
					idx := r.IntN(size)
					if !bitutil.BitIsSet(validBits, idx) {
						bitutil.SetBit(validBits, idx)
						validIdx++
					}
				}

				b.ResetTimer()
				b.ReportAllocs()

				for i := 0; i < b.N; i++ {
					hashes := GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
					bf.InsertBulk(hashes)
				}
			})
		}
	}
}

// BenchmarkBloomFilterCheckSpaced benchmarks checking spaced values in bloom filter
func BenchmarkBloomFilterCheckSpaced(b *testing.B) {
	sizes := []int{100, 1000, 10000}
	sparsities := []float64{0.5, 0.75, 0.9}

	for _, size := range sizes {
		for _, sparsity := range sparsities {
			b.Run(formatBenchName(size, sparsity), func(b *testing.B) {
				mem := memory.DefaultAllocator
				bf := NewBloomFilter(1024, maximumBloomFilterBytes, mem).(*blockSplitBloomFilter)
				h := bf.Hasher()

				// Create and insert test data
				vals := make([]int32, size)
				validBits := make([]byte, bitutil.BytesForBits(int64(size)))
				numValid := int(float64(size) * sparsity)

				r := rand.New(rand.NewPCG(42, 42))
				for i := range vals {
					vals[i] = r.Int32()
				}

				validIdx := 0
				for validIdx < numValid {
					idx := r.IntN(size)
					if !bitutil.BitIsSet(validBits, idx) {
						bitutil.SetBit(validBits, idx)
						validIdx++
					}
				}

				// Insert values
				hashes := GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
				bf.InsertBulk(hashes)

				b.ResetTimer()
				b.ReportAllocs()

				for i := 0; i < b.N; i++ {
					hashes := GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
					bf.CheckBulk(hashes)
				}
			})
		}
	}
}

// BenchmarkGetSpacedHashes benchmarks the GetSpacedHashes function specifically
// This is the hot path that benefits most from the pool optimization
func BenchmarkGetSpacedHashes(b *testing.B) {
	sizes := []int{100, 1000, 10000}
	sparsities := []float64{0.25, 0.5, 0.75, 0.9}

	for _, size := range sizes {
		for _, sparsity := range sparsities {
			b.Run(formatBenchName(size, sparsity), func(b *testing.B) {
				h := xxhasher{}

				// Create test data
				vals := make([]int32, size)
				validBits := make([]byte, bitutil.BytesForBits(int64(size)))
				numValid := int(float64(size) * sparsity)

				r := rand.New(rand.NewPCG(42, 42))
				for i := range vals {
					vals[i] = r.Int32()
				}

				validIdx := 0
				for validIdx < numValid {
					idx := r.IntN(size)
					if !bitutil.BitIsSet(validBits, idx) {
						bitutil.SetBit(validBits, idx)
						validIdx++
					}
				}

				b.ResetTimer()
				b.ReportAllocs()

				for i := 0; i < b.N; i++ {
					_ = GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
				}
			})
		}
	}
}

// BenchmarkGetSpacedHashesSequential tests the case where valid bits are sequential
// This represents a common case with fewer runs
func BenchmarkGetSpacedHashesSequential(b *testing.B) {
	sizes := []int{100, 1000, 10000}

	for _, size := range sizes {
		b.Run(formatBenchNameSize(size), func(b *testing.B) {
			h := xxhasher{}

			// Create sequential valid bits (first half is valid)
			vals := make([]int32, size)
			validBits := make([]byte, bitutil.BytesForBits(int64(size)))
			numValid := size / 2

			r := rand.New(rand.NewPCG(42, 42))
			for i := range vals {
				vals[i] = r.Int32()
			}

			// Set first half of bits
			for i := 0; i < numValid; i++ {
				bitutil.SetBit(validBits, i)
			}

			b.ResetTimer()
			b.ReportAllocs()

			for i := 0; i < b.N; i++ {
				_ = GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
			}
		})
	}
}

// BenchmarkGetSpacedHashesHighlyFragmented tests with maximum fragmentation
// Every other bit is set, creating many small runs
func BenchmarkGetSpacedHashesHighlyFragmented(b *testing.B) {
	sizes := []int{100, 1000, 10000}

	for _, size := range sizes {
		b.Run(formatBenchNameSize(size), func(b *testing.B) {
			h := xxhasher{}

			// Create alternating valid bits
			vals := make([]int32, size)
			validBits := make([]byte, bitutil.BytesForBits(int64(size)))
			numValid := size / 2

			r := rand.New(rand.NewPCG(42, 42))
			for i := range vals {
				vals[i] = r.Int32()
			}

			// Set every other bit
			for i := 0; i < size; i += 2 {
				bitutil.SetBit(validBits, i)
			}

			b.ResetTimer()
			b.ReportAllocs()

			for i := 0; i < b.N; i++ {
				_ = GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
			}
		})
	}
}

// BenchmarkGetSpacedHashesByteArray tests with ByteArray type (variable length)
func BenchmarkGetSpacedHashesByteArray(b *testing.B) {
	sizes := []int{100, 1000, 10000}
	sparsities := []float64{0.5, 0.75, 0.9}

	for _, size := range sizes {
		for _, sparsity := range sparsities {
			b.Run(formatBenchName(size, sparsity), func(b *testing.B) {
				h := xxhasher{}

				// Create test data with variable length byte arrays
				vals := make([]parquet.ByteArray, size)
				validBits := make([]byte, bitutil.BytesForBits(int64(size)))
				numValid := int(float64(size) * sparsity)

				r := rand.New(rand.NewPCG(42, 42))
				for i := range vals {
					length := r.IntN(20) + 5 // 5-25 bytes
					vals[i] = make([]byte, length)
					for j := range vals[i] {
						vals[i][j] = byte(r.Uint32())
					}
				}

				validIdx := 0
				for validIdx < numValid {
					idx := r.IntN(size)
					if !bitutil.BitIsSet(validBits, idx) {
						bitutil.SetBit(validBits, idx)
						validIdx++
					}
				}

				b.ResetTimer()
				b.ReportAllocs()

				for i := 0; i < b.N; i++ {
					_ = GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
				}
			})
		}
	}
}

// BenchmarkBloomFilterConcurrent tests thread safety of the pool
func BenchmarkBloomFilterConcurrent(b *testing.B) {
	h := xxhasher{}
	size := 1000
	sparsity := 0.75

	// Create test data
	vals := make([]int32, size)
	validBits := make([]byte, bitutil.BytesForBits(int64(size)))
	numValid := int(float64(size) * sparsity)

	r := rand.New(rand.NewPCG(42, 42))
	for i := range vals {
		vals[i] = r.Int32()
	}

	validIdx := 0
	for validIdx < numValid {
		idx := r.IntN(size)
		if !bitutil.BitIsSet(validBits, idx) {
			bitutil.SetBit(validBits, idx)
			validIdx++
		}
	}

	b.ResetTimer()
	b.ReportAllocs()

	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			_ = GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
		}
	})
}

// Helper functions to format benchmark names
func formatBenchName(size int, sparsity float64) string {
	return formatBenchNameSize(size) + formatSparsity(sparsity)
}

func formatBenchNameSize(size int) string {
	if size >= 10000 {
		return "10k"
	} else if size >= 1000 {
		return "1k"
	}
	return "100"
}

func formatSparsity(sparsity float64) string {
	switch sparsity {
	case 0.25:
		return "/sparse_25pct"
	case 0.5:
		return "/sparse_50pct"
	case 0.75:
		return "/sparse_75pct"
	case 0.9:
		return "/sparse_90pct"
	default:
		return ""
	}
}
