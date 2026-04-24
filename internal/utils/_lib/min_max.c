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

#include <arch.h>
#include <stdint.h>
#include <limits.h>
#include <math.h>
#include <float.h>

void FULL_NAME(int8_max_min)(const int8_t * __restrict__ values, int64_t len, int8_t * __restrict__ minout, int8_t * __restrict__ maxout) {
  int8_t max = INT8_MIN;
  int8_t min = INT8_MAX;

  for (int64_t i = 0; i < len; ++i) {
    min = min < values[i] ? min : values[i];
    max = max > values[i] ? max : values[i];
  }

  *maxout = max;
  *minout = min;
}

void FULL_NAME(uint8_max_min)(const uint8_t * __restrict__ values, int64_t len, uint8_t * __restrict__ minout, uint8_t * __restrict__ maxout) {
  uint8_t max = 0;
  uint8_t min = UINT8_MAX;

  for (int64_t i = 0; i < len; ++i) {
    min = min < values[i] ? min : values[i];
    max = max > values[i] ? max : values[i];
  }

  *maxout = max;
  *minout = min;
}

void FULL_NAME(int16_max_min)(const int16_t * __restrict__ values, int64_t len, int16_t * __restrict__ minout, int16_t * __restrict__ maxout) {
  int16_t max = INT16_MIN;
  int16_t min = INT16_MAX;

  for (int64_t i = 0; i < len; ++i) {
    min = min < values[i] ? min : values[i];
    max = max > values[i] ? max : values[i];
  }

  *maxout = max;
  *minout = min;
}

void FULL_NAME(uint16_max_min)(const uint16_t * __restrict__ values, int64_t len, uint16_t * __restrict__ minout, uint16_t * __restrict__ maxout) {
  uint16_t max = 0;
  uint16_t min = UINT16_MAX;

  for (int64_t i = 0; i < len; ++i) {
    min = min < values[i] ? min : values[i];
    max = max > values[i] ? max : values[i];
  }

  *maxout = max;
  *minout = min;
}

void FULL_NAME(int32_max_min)(const int32_t * __restrict__ values, int64_t len, int32_t * __restrict__ minout, int32_t * __restrict__ maxout) {
  int32_t max = INT32_MIN;
  int32_t min = INT32_MAX;

  for (int64_t i = 0; i < len; ++i) {
    min = min < values[i] ? min : values[i];
    max = max > values[i] ? max : values[i];
  }

  *maxout = max;
  *minout = min;
}

void FULL_NAME(uint32_max_min)(const uint32_t * __restrict__ values, int64_t len, uint32_t * __restrict__ minout, uint32_t * __restrict__ maxout) {
  uint32_t max = 0;
  uint32_t min = UINT32_MAX;

  for (int64_t i = 0; i < len; ++i) {
    min = min < values[i] ? min : values[i];
    max = max > values[i] ? max : values[i];
  }

  *maxout = max;
  *minout = min;
}

void FULL_NAME(int64_max_min)(const int64_t * __restrict__ values, int64_t len, int64_t * __restrict__ minout, int64_t * __restrict__ maxout) {
  int64_t max = INT64_MIN;
  int64_t min = INT64_MAX;

  for (int64_t i = 0; i < len; ++i) {
    min = min < values[i] ? min : values[i];
    max = max > values[i] ? max : values[i];
  }

  *maxout = max;
  *minout = min;
}

void FULL_NAME(uint64_max_min)(const uint64_t * __restrict__ values, int64_t len, uint64_t * __restrict__ minout, uint64_t * __restrict__ maxout) {
  uint64_t max = 0;
  uint64_t min = UINT64_MAX;

  for (int64_t i = 0; i < len; ++i) {
    min = min < values[i] ? min : values[i];
    max = max > values[i] ? max : values[i];
  }

  *maxout = max;
  *minout = min;
}
