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

//go:build !noasm

package utils

import (
	"fmt"
	"testing"
	"unsafe"
)

func BenchmarkUnpack32AVX2(b *testing.B) {
	for _, nbits := range []int{1, 2, 3, 4, 5, 8, 12, 16, 24, 32} {
		nvalues := 1024
		inputBytes := nvalues * nbits / 8
		if inputBytes == 0 {
			inputBytes = 1
		}
		input := make([]byte, inputBytes+32)
		output := make([]uint32, nvalues)
		for i := range input {
			input[i] = byte(i * 137)
		}

		b.Run(fmt.Sprintf("bits=%d", nbits), func(b *testing.B) {
			b.SetBytes(int64(nvalues * 4))
			for i := 0; i < b.N; i++ {
				_unpack32_avx2(
					unsafe.Pointer(&input[0]),
					unsafe.Pointer(&output[0]),
					nvalues, nbits)
			}
		})
	}
}
