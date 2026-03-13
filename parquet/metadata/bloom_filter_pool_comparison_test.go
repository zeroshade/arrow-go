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
	"github.com/apache/arrow-go/v18/internal/bitutils"
	"github.com/apache/arrow-go/v18/parquet"
)

// GetSpacedHashesNoPool is the original implementation without pooling
// This allows us to benchmark the difference
func GetSpacedHashesNoPool[T parquet.ColumnTypes](h Hasher, numValid int64, vals []T, validBits []byte, validBitsOffset int64) []uint64 {
	if numValid == 0 {
		return []uint64{}
	}

	out := make([]uint64, 0, numValid)

	// Original implementation - creates new reader every time
	setReader := bitutils.NewSetBitRunReader(validBits, validBitsOffset, int64(len(vals)))
	for {
		run := setReader.NextRun()
		if run.Length == 0 {
			break
		}

		out = append(out, h.Sum64s(getBytesSlice(vals[run.Pos:run.Pos+run.Length]))...)
	}
	return out
}

// BenchmarkGetSpacedHashesPooled tests the pooled version
func BenchmarkGetSpacedHashesPooled(b *testing.B) {
	benchSpacedHashesVariants(b, false)
}

// BenchmarkGetSpacedHashesNoPool tests the non-pooled version
func BenchmarkGetSpacedHashesNoPool(b *testing.B) {
	benchSpacedHashesVariants(b, true)
}

func benchSpacedHashesVariants(b *testing.B, noPool bool) {
	sizes := []struct {
		name     string
		size     int
		sparsity float64
	}{
		{"100_sparse_50pct", 100, 0.5},
		{"1k_sparse_50pct", 1000, 0.5},
		{"10k_sparse_50pct", 10000, 0.5},
		{"1k_sparse_25pct", 1000, 0.25},
		{"1k_sparse_75pct", 1000, 0.75},
		{"1k_sparse_90pct", 1000, 0.9},
	}

	for _, tc := range sizes {
		b.Run(tc.name, func(b *testing.B) {
			h := xxhasher{}

			// Create test data
			vals := make([]int32, tc.size)
			validBits := make([]byte, bitutil.BytesForBits(int64(tc.size)))
			numValid := int(float64(tc.size) * tc.sparsity)

			r := rand.New(rand.NewPCG(42, 42))
			for i := range vals {
				vals[i] = r.Int32()
			}

			validIdx := 0
			for validIdx < numValid {
				idx := r.IntN(tc.size)
				if !bitutil.BitIsSet(validBits, idx) {
					bitutil.SetBit(validBits, idx)
					validIdx++
				}
			}

			b.ResetTimer()
			b.ReportAllocs()

			for i := 0; i < b.N; i++ {
				var hashes []uint64
				if noPool {
					hashes = GetSpacedHashesNoPool(h, int64(numValid), vals, validBits, 0)
				} else {
					hashes = GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
				}
				_ = hashes
			}
		})
	}
}

// BenchmarkGetSpacedHashesPooledByteArray tests with ByteArray for the pooled version
func BenchmarkGetSpacedHashesPooledByteArray(b *testing.B) {
	benchSpacedHashesByteArrayVariants(b, false)
}

// BenchmarkGetSpacedHashesNoPoolByteArray tests with ByteArray for the non-pooled version
func BenchmarkGetSpacedHashesNoPoolByteArray(b *testing.B) {
	benchSpacedHashesByteArrayVariants(b, true)
}

func benchSpacedHashesByteArrayVariants(b *testing.B, noPool bool) {
	sizes := []struct {
		name     string
		size     int
		sparsity float64
	}{
		{"1k_sparse_50pct", 1000, 0.5},
		{"1k_sparse_75pct", 1000, 0.75},
		{"10k_sparse_50pct", 10000, 0.5},
	}

	for _, tc := range sizes {
		b.Run(tc.name, func(b *testing.B) {
			h := xxhasher{}

			// Create test data with variable length byte arrays
			vals := make([]parquet.ByteArray, tc.size)
			validBits := make([]byte, bitutil.BytesForBits(int64(tc.size)))
			numValid := int(float64(tc.size) * tc.sparsity)

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
				idx := r.IntN(tc.size)
				if !bitutil.BitIsSet(validBits, idx) {
					bitutil.SetBit(validBits, idx)
					validIdx++
				}
			}

			b.ResetTimer()
			b.ReportAllocs()

			for i := 0; i < b.N; i++ {
				var hashes []uint64
				if noPool {
					hashes = GetSpacedHashesNoPool(h, int64(numValid), vals, validBits, 0)
				} else {
					hashes = GetSpacedHashes(h, int64(numValid), vals, validBits, 0)
				}
				_ = hashes
			}
		})
	}
}
