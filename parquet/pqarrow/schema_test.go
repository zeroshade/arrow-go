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

package pqarrow_test

import (
	"encoding/base64"
	"testing"

	"github.com/apache/arrow-go/v18/arrow"
	"github.com/apache/arrow-go/v18/arrow/extensions"
	"github.com/apache/arrow-go/v18/arrow/flight"
	"github.com/apache/arrow-go/v18/arrow/ipc"
	"github.com/apache/arrow-go/v18/arrow/memory"
	"github.com/apache/arrow-go/v18/parquet"
	"github.com/apache/arrow-go/v18/parquet/metadata"
	"github.com/apache/arrow-go/v18/parquet/pqarrow"
	"github.com/apache/arrow-go/v18/parquet/schema"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGetOriginSchemaBase64(t *testing.T) {
	uuidType := extensions.NewUUIDType()
	md := arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"-1"})
	extMd := arrow.NewMetadata([]string{ipc.ExtensionMetadataKeyName, ipc.ExtensionTypeKeyName, "PARQUET:field_id"}, []string{uuidType.Serialize(), uuidType.ExtensionName(), "-1"})
	origArrSc := arrow.NewSchema([]arrow.Field{
		{Name: "f1", Type: arrow.BinaryTypes.String, Metadata: md},
		{Name: "f2", Type: arrow.PrimitiveTypes.Int64, Metadata: md},
		{Name: "uuid", Type: uuidType, Metadata: extMd},
	}, nil)

	arrSerializedSc := flight.SerializeSchema(origArrSc, memory.DefaultAllocator)
	pqschema, err := pqarrow.ToParquet(origArrSc, nil, pqarrow.DefaultWriterProps())
	require.NoError(t, err)

	tests := []struct {
		name string
		enc  *base64.Encoding
	}{
		{"raw", base64.RawStdEncoding},
		{"std", base64.StdEncoding},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			kv := metadata.NewKeyValueMetadata()
			kv.Append("ARROW:schema", tt.enc.EncodeToString(arrSerializedSc))
			arrsc, err := pqarrow.FromParquet(pqschema, nil, kv)
			assert.NoError(t, err)
			assert.True(t, origArrSc.Equal(arrsc))
		})
	}
}

func TestGetOriginSchemaUnregisteredExtension(t *testing.T) {
	uuidType := extensions.NewUUIDType()
	md := arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"-1"})
	origArrSc := arrow.NewSchema([]arrow.Field{
		{Name: "f1", Type: arrow.BinaryTypes.String, Metadata: md},
		{Name: "f2", Type: arrow.PrimitiveTypes.Int64, Metadata: md},
		{Name: "uuid", Type: uuidType, Metadata: md},
	}, nil)
	pqschema, err := pqarrow.ToParquet(origArrSc, nil, pqarrow.DefaultWriterProps())
	require.NoError(t, err)

	arrSerializedSc := flight.SerializeSchema(origArrSc, memory.DefaultAllocator)
	kv := metadata.NewKeyValueMetadata()
	kv.Append("ARROW:schema", base64.StdEncoding.EncodeToString(arrSerializedSc))

	arrow.UnregisterExtensionType(uuidType.ExtensionName())
	defer arrow.RegisterExtensionType(uuidType)
	arrsc, err := pqarrow.FromParquet(pqschema, nil, kv)
	require.NoError(t, err)

	extMd := arrow.NewMetadata([]string{ipc.ExtensionMetadataKeyName, ipc.ExtensionTypeKeyName, "PARQUET:field_id"},
		[]string{uuidType.Serialize(), uuidType.ExtensionName(), "-1"})
	expArrSc := arrow.NewSchema([]arrow.Field{
		{Name: "f1", Type: arrow.BinaryTypes.String, Metadata: md},
		{Name: "f2", Type: arrow.PrimitiveTypes.Int64, Metadata: md},
		{Name: "uuid", Type: uuidType.StorageType(), Metadata: extMd},
	}, nil)

	assert.Truef(t, expArrSc.Equal(arrsc), "expected: %s\ngot: %s", expArrSc, arrsc)
}

func TestToParquetWriterConfig(t *testing.T) {
	origSc := arrow.NewSchema([]arrow.Field{
		{Name: "f1", Type: arrow.BinaryTypes.String},
		{Name: "f2", Type: arrow.PrimitiveTypes.Int64},
	}, nil)

	tests := []struct {
		name           string
		rootRepetition parquet.Repetition
	}{
		{"test1", parquet.Repetitions.Required},
		{"test2", parquet.Repetitions.Repeated},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {

			pqschema, err := pqarrow.ToParquet(origSc,
				parquet.NewWriterProperties(
					parquet.WithRootName(tt.name),
					parquet.WithRootRepetition(tt.rootRepetition),
				),
				pqarrow.DefaultWriterProps())
			require.NoError(t, err)

			assert.Equal(t, tt.name, pqschema.Root().Name())
			assert.Equal(t, tt.rootRepetition, pqschema.Root().RepetitionType())
		})
	}
}

func TestConvertArrowFlatPrimitives(t *testing.T) {
	parquetFields := make(schema.FieldList, 0)
	arrowFields := make([]arrow.Field, 0)

	parquetFields = append(parquetFields, schema.NewBooleanNode("boolean", parquet.Repetitions.Required, -1))
	arrowFields = append(arrowFields, arrow.Field{Name: "boolean", Type: arrow.FixedWidthTypes.Boolean, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("int8", parquet.Repetitions.Required,
		schema.NewIntLogicalType(8, true), parquet.Types.Int32, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "int8", Type: arrow.PrimitiveTypes.Int8, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("uint8", parquet.Repetitions.Required,
		schema.NewIntLogicalType(8, false), parquet.Types.Int32, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "uint8", Type: arrow.PrimitiveTypes.Uint8, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("int16", parquet.Repetitions.Required,
		schema.NewIntLogicalType(16, true), parquet.Types.Int32, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "int16", Type: arrow.PrimitiveTypes.Int16, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("uint16", parquet.Repetitions.Required,
		schema.NewIntLogicalType(16, false), parquet.Types.Int32, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "uint16", Type: arrow.PrimitiveTypes.Uint16, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("int32", parquet.Repetitions.Required,
		schema.NewIntLogicalType(32, true), parquet.Types.Int32, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "int32", Type: arrow.PrimitiveTypes.Int32, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("uint32", parquet.Repetitions.Required,
		schema.NewIntLogicalType(32, false), parquet.Types.Int32, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "uint32", Type: arrow.PrimitiveTypes.Uint32, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("int64", parquet.Repetitions.Required,
		schema.NewIntLogicalType(64, true), parquet.Types.Int64, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "int64", Type: arrow.PrimitiveTypes.Int64, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("uint64", parquet.Repetitions.Required,
		schema.NewIntLogicalType(64, false), parquet.Types.Int64, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "uint64", Type: arrow.PrimitiveTypes.Uint64, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeConverted("timestamp", parquet.Repetitions.Required,
		parquet.Types.Int64, schema.ConvertedTypes.TimestampMillis, 0, 0, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "timestamp", Type: arrow.FixedWidthTypes.Timestamp_ms, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeConverted("timestamp[us]", parquet.Repetitions.Required,
		parquet.Types.Int64, schema.ConvertedTypes.TimestampMicros, 0, 0, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "timestamp[us]", Type: arrow.FixedWidthTypes.Timestamp_us, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("date", parquet.Repetitions.Required,
		schema.DateLogicalType{}, parquet.Types.Int32, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "date", Type: arrow.FixedWidthTypes.Date32, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("date64", parquet.Repetitions.Required,
		schema.DateLogicalType{}, parquet.Types.Int32, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "date64", Type: arrow.FixedWidthTypes.Date64, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("time32", parquet.Repetitions.Required,
		schema.NewTimeLogicalType(true, schema.TimeUnitMillis), parquet.Types.Int32, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "time32", Type: arrow.FixedWidthTypes.Time32ms, Nullable: false})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("time64", parquet.Repetitions.Required,
		schema.NewTimeLogicalType(true, schema.TimeUnitMicros), parquet.Types.Int64, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "time64", Type: arrow.FixedWidthTypes.Time64us, Nullable: false})

	parquetFields = append(parquetFields, schema.NewInt96Node("timestamp96", parquet.Repetitions.Required, -1))
	arrowFields = append(arrowFields, arrow.Field{Name: "timestamp96", Type: arrow.FixedWidthTypes.Timestamp_ns, Nullable: false})

	parquetFields = append(parquetFields, schema.NewFloat32Node("float", parquet.Repetitions.Optional, -1))
	arrowFields = append(arrowFields, arrow.Field{Name: "float", Type: arrow.PrimitiveTypes.Float32, Nullable: true})

	parquetFields = append(parquetFields, schema.NewFloat64Node("double", parquet.Repetitions.Optional, -1))
	arrowFields = append(arrowFields, arrow.Field{Name: "double", Type: arrow.PrimitiveTypes.Float64, Nullable: true})

	parquetFields = append(parquetFields, schema.NewByteArrayNode("binary", parquet.Repetitions.Optional, -1))
	arrowFields = append(arrowFields, arrow.Field{Name: "binary", Type: arrow.BinaryTypes.Binary, Nullable: true})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("string", parquet.Repetitions.Optional,
		schema.StringLogicalType{}, parquet.Types.ByteArray, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "string", Type: arrow.BinaryTypes.String, Nullable: true})

	parquetFields = append(parquetFields, schema.NewFixedLenByteArrayNode("flba-binary", parquet.Repetitions.Optional, 12, -1))
	arrowFields = append(arrowFields, arrow.Field{Name: "flba-binary", Type: &arrow.FixedSizeBinaryType{ByteWidth: 12}, Nullable: true})

	arrowSchema := arrow.NewSchema(arrowFields, nil)
	parquetSchema := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("schema", parquet.Repetitions.Repeated, parquetFields, -1)))

	result, err := pqarrow.ToParquet(arrowSchema, nil, pqarrow.NewArrowWriterProperties(pqarrow.WithDeprecatedInt96Timestamps(true)))
	assert.NoError(t, err)
	assert.True(t, parquetSchema.Equals(result))
	for i := 0; i < parquetSchema.NumColumns(); i++ {
		assert.Truef(t, parquetSchema.Column(i).Equals(result.Column(i)), "Column %d didn't match: %s", i, parquetSchema.Column(i).Name())
	}
}

func TestConvertArrowParquetLists(t *testing.T) {
	parquetFields := make(schema.FieldList, 0)
	arrowFields := make([]arrow.Field, 0)

	parquetFields = append(parquetFields, schema.MustGroup(schema.ListOf(schema.Must(schema.NewPrimitiveNodeLogical("my_list",
		parquet.Repetitions.Optional, schema.StringLogicalType{}, parquet.Types.ByteArray, 0, -1)), parquet.Repetitions.Required, -1)))

	arrowFields = append(arrowFields, arrow.Field{Name: "my_list", Type: arrow.ListOf(arrow.BinaryTypes.String)})

	parquetFields = append(parquetFields, schema.MustGroup(schema.ListOf(schema.Must(schema.NewPrimitiveNodeLogical("my_list",
		parquet.Repetitions.Optional, schema.StringLogicalType{}, parquet.Types.ByteArray, 0, -1)), parquet.Repetitions.Optional, -1)))

	arrowFields = append(arrowFields, arrow.Field{Name: "my_list", Type: arrow.ListOf(arrow.BinaryTypes.String), Nullable: true})

	arrowSchema := arrow.NewSchema(arrowFields, nil)
	parquetSchema := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("schema", parquet.Repetitions.Repeated, parquetFields, -1)))

	result, err := pqarrow.ToParquet(arrowSchema, nil, pqarrow.NewArrowWriterProperties(pqarrow.WithDeprecatedInt96Timestamps(true)))
	assert.NoError(t, err)
	assert.True(t, parquetSchema.Equals(result), parquetSchema.String(), result.String())
	for i := 0; i < parquetSchema.NumColumns(); i++ {
		assert.Truef(t, parquetSchema.Column(i).Equals(result.Column(i)), "Column %d didn't match: %s", i, parquetSchema.Column(i).Name())
	}
}

func TestConvertArrowDecimals(t *testing.T) {
	parquetFields := make(schema.FieldList, 0)
	arrowFields := make([]arrow.Field, 0)

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("decimal_8_4", parquet.Repetitions.Required,
		schema.NewDecimalLogicalType(8, 4), parquet.Types.FixedLenByteArray, 4, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "decimal_8_4", Type: &arrow.Decimal128Type{Precision: 8, Scale: 4}})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("decimal_20_4", parquet.Repetitions.Required,
		schema.NewDecimalLogicalType(20, 4), parquet.Types.FixedLenByteArray, 9, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "decimal_20_4", Type: &arrow.Decimal128Type{Precision: 20, Scale: 4}})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("decimal_77_4", parquet.Repetitions.Required,
		schema.NewDecimalLogicalType(77, 4), parquet.Types.FixedLenByteArray, 34, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "decimal_77_4", Type: &arrow.Decimal128Type{Precision: 77, Scale: 4}})

	arrowSchema := arrow.NewSchema(arrowFields, nil)
	parquetSchema := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("schema", parquet.Repetitions.Repeated, parquetFields, -1)))

	result, err := pqarrow.ToParquet(arrowSchema, nil, pqarrow.NewArrowWriterProperties(pqarrow.WithDeprecatedInt96Timestamps(true)))
	assert.NoError(t, err)
	assert.True(t, parquetSchema.Equals(result))
	for i := 0; i < parquetSchema.NumColumns(); i++ {
		assert.Truef(t, parquetSchema.Column(i).Equals(result.Column(i)), "Column %d didn't match: %s", i, parquetSchema.Column(i).Name())
	}
}

func TestConvertArrowFloat16(t *testing.T) {
	parquetFields := make(schema.FieldList, 0)
	arrowFields := make([]arrow.Field, 0)

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("float16", parquet.Repetitions.Required,
		schema.Float16LogicalType{}, parquet.Types.FixedLenByteArray, 2, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "float16", Type: &arrow.Float16Type{}})

	arrowSchema := arrow.NewSchema(arrowFields, nil)
	parquetSchema := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("schema", parquet.Repetitions.Repeated, parquetFields, -1)))

	result, err := pqarrow.ToParquet(arrowSchema, nil, pqarrow.NewArrowWriterProperties(pqarrow.WithDeprecatedInt96Timestamps(true)))
	assert.NoError(t, err)
	assert.True(t, parquetSchema.Equals(result))
	for i := 0; i < parquetSchema.NumColumns(); i++ {
		assert.Truef(t, parquetSchema.Column(i).Equals(result.Column(i)), "Column %d didn't match: %s", i, parquetSchema.Column(i).Name())
	}
}

func TestCoerceTimestampV1(t *testing.T) {
	parquetFields := make(schema.FieldList, 0)
	arrowFields := make([]arrow.Field, 0)

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("timestamp", parquet.Repetitions.Required,
		schema.NewTimestampLogicalTypeForce(true, schema.TimeUnitMicros), parquet.Types.Int64, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "timestamp", Type: &arrow.TimestampType{Unit: arrow.Millisecond, TimeZone: "EST"}})

	arrowSchema := arrow.NewSchema(arrowFields, nil)
	parquetSchema := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("schema", parquet.Repetitions.Repeated, parquetFields, -1)))

	result, err := pqarrow.ToParquet(arrowSchema, parquet.NewWriterProperties(parquet.WithVersion(parquet.V1_0)), pqarrow.NewArrowWriterProperties(pqarrow.WithCoerceTimestamps(arrow.Microsecond)))
	assert.NoError(t, err)
	assert.True(t, parquetSchema.Equals(result))
	for i := 0; i < parquetSchema.NumColumns(); i++ {
		assert.Truef(t, parquetSchema.Column(i).Equals(result.Column(i)), "Column %d didn't match: %s", i, parquetSchema.Column(i).Name())
	}
}

func TestAutoCoerceTimestampV1(t *testing.T) {
	parquetFields := make(schema.FieldList, 0)
	arrowFields := make([]arrow.Field, 0)

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("timestamp", parquet.Repetitions.Required,
		schema.NewTimestampLogicalTypeForce(true, schema.TimeUnitMicros), parquet.Types.Int64, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "timestamp", Type: &arrow.TimestampType{Unit: arrow.Nanosecond, TimeZone: "EST"}})

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("timestamp[ms]", parquet.Repetitions.Required,
		schema.NewTimestampLogicalTypeForce(false, schema.TimeUnitMillis), parquet.Types.Int64, 0, -1)))
	arrowFields = append(arrowFields, arrow.Field{Name: "timestamp[ms]", Type: &arrow.TimestampType{Unit: arrow.Second}})

	arrowSchema := arrow.NewSchema(arrowFields, nil)
	parquetSchema := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("schema", parquet.Repetitions.Repeated, parquetFields, -1)))

	result, err := pqarrow.ToParquet(arrowSchema, parquet.NewWriterProperties(parquet.WithVersion(parquet.V1_0)), pqarrow.NewArrowWriterProperties())
	assert.NoError(t, err)
	assert.True(t, parquetSchema.Equals(result))
	for i := 0; i < parquetSchema.NumColumns(); i++ {
		assert.Truef(t, parquetSchema.Column(i).Equals(result.Column(i)), "Column %d didn't match: %s", i, parquetSchema.Column(i).Name())
	}
}

func TestConvertArrowStruct(t *testing.T) {
	parquetFields := make(schema.FieldList, 0)
	arrowFields := make([]arrow.Field, 0)

	parquetFields = append(parquetFields, schema.Must(schema.NewPrimitiveNodeLogical("leaf1", parquet.Repetitions.Optional, schema.NewIntLogicalType(32, true), parquet.Types.Int32, 0, -1)))
	parquetFields = append(parquetFields, schema.Must(schema.NewGroupNode("outerGroup", parquet.Repetitions.Required, schema.FieldList{
		schema.Must(schema.NewPrimitiveNodeLogical("leaf2", parquet.Repetitions.Optional, schema.NewIntLogicalType(32, true), parquet.Types.Int32, 0, -1)),
		schema.Must(schema.NewGroupNode("innerGroup", parquet.Repetitions.Required, schema.FieldList{
			schema.Must(schema.NewPrimitiveNodeLogical("leaf3", parquet.Repetitions.Optional, schema.NewIntLogicalType(32, true), parquet.Types.Int32, 0, -1)),
		}, -1)),
	}, -1)))

	arrowFields = append(arrowFields, arrow.Field{Name: "leaf1", Type: arrow.PrimitiveTypes.Int32, Nullable: true})
	arrowFields = append(arrowFields, arrow.Field{Name: "outerGroup", Type: arrow.StructOf(
		arrow.Field{Name: "leaf2", Type: arrow.PrimitiveTypes.Int32, Nullable: true},
		arrow.Field{Name: "innerGroup", Type: arrow.StructOf(
			arrow.Field{Name: "leaf3", Type: arrow.PrimitiveTypes.Int32, Nullable: true},
		)},
	)})

	arrowSchema := arrow.NewSchema(arrowFields, nil)
	parquetSchema := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("schema", parquet.Repetitions.Repeated, parquetFields, -1)))

	result, err := pqarrow.ToParquet(arrowSchema, nil, pqarrow.NewArrowWriterProperties())
	assert.NoError(t, err)
	assert.True(t, parquetSchema.Equals(result))
	for i := 0; i < parquetSchema.NumColumns(); i++ {
		assert.Truef(t, parquetSchema.Column(i).Equals(result.Column(i)), "Column %d didn't match: %s", i, parquetSchema.Column(i).Name())
	}
}

func TestListStructBackwardCompatible(t *testing.T) {
	// Set up old construction for list of struct, not using
	// the 3-level encoding. Schema looks like:
	//
	//     required group field_id=-1 root {
	//       optional group field_id=1 answers (List) {
	//		   repeated group field_id=-1 array {
	//           optional byte_array field_id=2 type (String);
	//           optional byte_array field_id=3 rdata (String);
	//           optional byte_array field_id=4 class (String);
	//         }
	//       }
	//     }
	//
	// Instead of the proper 3-level encoding which would be:
	//
	//     repeated group field_id=-1 schema {
	//       optional group field_id=1 answers (List) {
	//         repeated group field_id=-1 list {
	//           optional group field_id=-1 element {
	//             optional byte_array field_id=2 type (String);
	//             optional byte_array field_id=3 rdata (String);
	//             optional byte_array field_id=4 class (String);
	//           }
	//         }
	//       }
	//     }
	//
	pqSchema := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("root", parquet.Repetitions.Required, schema.FieldList{
		schema.Must(schema.NewGroupNodeLogical("answers", parquet.Repetitions.Optional, schema.FieldList{
			schema.Must(schema.NewGroupNode("array", parquet.Repetitions.Repeated, schema.FieldList{
				schema.MustPrimitive(schema.NewPrimitiveNodeLogical("type", parquet.Repetitions.Optional,
					schema.StringLogicalType{}, parquet.Types.ByteArray, -1, 2)),
				schema.MustPrimitive(schema.NewPrimitiveNodeLogical("rdata", parquet.Repetitions.Optional,
					schema.StringLogicalType{}, parquet.Types.ByteArray, -1, 3)),
				schema.MustPrimitive(schema.NewPrimitiveNodeLogical("class", parquet.Repetitions.Optional,
					schema.StringLogicalType{}, parquet.Types.ByteArray, -1, 4)),
			}, 5)),
		}, schema.NewListLogicalType(), 1)),
	}, -1)))

	// desired equivalent arrow schema would be list<item: struct<type: utf8, rdata: utf8, class: utf8>>
	arrowSchema := arrow.NewSchema(
		[]arrow.Field{
			{Name: "answers", Type: arrow.ListOfField(arrow.Field{
				Name: "array", Type: arrow.StructOf(
					arrow.Field{Name: "type", Type: arrow.BinaryTypes.String, Nullable: true,
						Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"2"})},
					arrow.Field{Name: "rdata", Type: arrow.BinaryTypes.String, Nullable: true,
						Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"3"})},
					arrow.Field{Name: "class", Type: arrow.BinaryTypes.String, Nullable: true,
						Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"4"})},
				), Nullable: true, Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"5"})}),
				Nullable: true, Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"1"})},
		}, nil)

	arrsc, err := pqarrow.FromParquet(pqSchema, nil, metadata.KeyValueMetadata{})
	assert.NoError(t, err)
	assert.True(t, arrowSchema.Equal(arrsc), arrowSchema.String(), arrsc.String())
}

// TestUnsupportedTypes tests the error message for unsupported types. This test should be updated
// when support for these types is added.
func TestUnsupportedTypes(t *testing.T) {
	unsupportedTypes := []struct {
		typ arrow.DataType
	}{
		// Non-exhaustive list of unsupported types
		{typ: &arrow.DurationType{}},
		{typ: &arrow.DayTimeIntervalType{}},
		{typ: &arrow.MonthIntervalType{}},
		{typ: &arrow.MonthDayNanoIntervalType{}},
		{typ: &arrow.DenseUnionType{}},
		{typ: &arrow.SparseUnionType{}},
	}
	for _, tc := range unsupportedTypes {
		t.Run(tc.typ.ID().String(), func(t *testing.T) {
			arrowFields := make([]arrow.Field, 0)
			arrowFields = append(arrowFields, arrow.Field{Name: "unsupported", Type: tc.typ, Nullable: true})
			arrowSchema := arrow.NewSchema(arrowFields, nil)
			_, err := pqarrow.ToParquet(arrowSchema, nil, pqarrow.NewArrowWriterProperties())
			assert.ErrorIs(t, err, arrow.ErrNotImplemented)
			assert.ErrorContains(t, err, "support for "+tc.typ.ID().String())
		})
	}
}

func TestProperListElementNullability(t *testing.T) {
	arrSchema := arrow.NewSchema([]arrow.Field{
		{Name: "qux", Type: arrow.ListOfField(
			arrow.Field{
				Name:     "element",
				Type:     arrow.BinaryTypes.String,
				Nullable: false,
				Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"-1"})}),
			Nullable: false, Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"-1"})},
	}, nil)

	pqSchema, err := pqarrow.ToParquet(arrSchema, nil, pqarrow.DefaultWriterProps())
	require.NoError(t, err)
	assert.EqualValues(t, 1, pqSchema.Column(0).MaxDefinitionLevel())
	assert.Equal(t, parquet.Repetitions.Required, pqSchema.Column(0).SchemaNode().RepetitionType())

	outSchema, err := pqarrow.FromParquet(pqSchema, nil, metadata.KeyValueMetadata{})
	require.NoError(t, err)
	assert.True(t, arrSchema.Equal(outSchema), "expected: %s, got: %s", arrSchema, outSchema)
}

func TestFieldNestedPropagate(t *testing.T) {
	arrSchema := arrow.NewSchema([]arrow.Field{
		{Name: "transformations", Type: arrow.ListOfField(
			arrow.Field{
				Name: "element",
				Type: arrow.StructOf(
					arrow.Field{Name: "destination", Type: arrow.BinaryTypes.String,
						Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"6"})},
					arrow.Field{Name: "transform_type", Type: arrow.BinaryTypes.String,
						Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"7"})},
					arrow.Field{Name: "transform_value", Type: arrow.BinaryTypes.String,
						Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"8"})},
					arrow.Field{Name: "source_cols", Type: arrow.ListOfField(
						arrow.Field{Name: "element", Type: arrow.BinaryTypes.String, Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"10"})}),
						Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"9"})},
				),
				Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"5"}),
			},
		), Metadata: arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"4"})},
	}, nil)

	pqSchema, err := pqarrow.ToParquet(arrSchema, nil, pqarrow.DefaultWriterProps())
	require.NoError(t, err)

	result, err := pqarrow.FromParquet(pqSchema, nil, metadata.KeyValueMetadata{})
	require.NoError(t, err)

	assert.True(t, arrSchema.Equal(result), "expected: %s, got: %s", arrSchema, result)
}

func TestConvertSchemaParquetVariant(t *testing.T) {
	// unshredded variant:
	// optional group variant_col {
	//   required binary metadata;
	//   required binary value;
	// }
	//
	// shredded variants will be added later
	parquetFields := make(schema.FieldList, 0)
	metadata := schema.NewByteArrayNode("metadata", parquet.Repetitions.Required, -1)
	value := schema.NewByteArrayNode("value", parquet.Repetitions.Required, -1)

	variant, err := schema.NewGroupNodeLogical("variant_unshredded", parquet.Repetitions.Optional,
		schema.FieldList{metadata, value}, schema.VariantLogicalType{}, -1)
	require.NoError(t, err)
	parquetFields = append(parquetFields, variant)

	pqschema := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("schema", parquet.Repetitions.Required, parquetFields, -1)))
	outSchema, err := pqarrow.FromParquet(pqschema, nil, nil)
	require.NoError(t, err)

	assert.EqualValues(t, 1, outSchema.NumFields())
	assert.Equal(t, "variant_unshredded", outSchema.Field(0).Name)
	assert.Equal(t, arrow.EXTENSION, outSchema.Field(0).Type.ID())

	assert.Equal(t, "parquet.variant", outSchema.Field(0).Type.(arrow.ExtensionType).ExtensionName())

	sc, err := pqarrow.ToParquet(outSchema, nil, pqarrow.DefaultWriterProps())
	require.NoError(t, err)
	assert.True(t, pqschema.Equals(sc), pqschema.String(), sc.String())
}

func TestShreddedVariantSchema(t *testing.T) {
	metaNoFieldID := arrow.NewMetadata([]string{"PARQUET:field_id"}, []string{"-1"})

	s := arrow.StructOf(
		arrow.Field{Name: "metadata", Type: arrow.BinaryTypes.Binary, Metadata: metaNoFieldID},
		arrow.Field{Name: "value", Type: arrow.BinaryTypes.Binary, Nullable: true, Metadata: metaNoFieldID},
		arrow.Field{Name: "typed_value", Type: arrow.StructOf(
			arrow.Field{Name: "tsmicro", Type: arrow.StructOf(
				arrow.Field{Name: "value", Type: arrow.BinaryTypes.Binary, Nullable: true, Metadata: metaNoFieldID},
				arrow.Field{Name: "typed_value", Type: arrow.FixedWidthTypes.Timestamp_us, Nullable: true, Metadata: metaNoFieldID},
			), Metadata: metaNoFieldID},
			arrow.Field{Name: "strval", Type: arrow.StructOf(
				arrow.Field{Name: "value", Type: arrow.BinaryTypes.Binary, Nullable: true, Metadata: metaNoFieldID},
				arrow.Field{Name: "typed_value", Type: arrow.BinaryTypes.String, Nullable: true, Metadata: metaNoFieldID},
			), Metadata: metaNoFieldID},
			arrow.Field{Name: "bool", Type: arrow.StructOf(
				arrow.Field{Name: "value", Type: arrow.BinaryTypes.Binary, Nullable: true, Metadata: metaNoFieldID},
				arrow.Field{Name: "typed_value", Type: arrow.FixedWidthTypes.Boolean, Nullable: true, Metadata: metaNoFieldID},
			), Metadata: metaNoFieldID},
			arrow.Field{Name: "uuid", Type: arrow.StructOf(
				arrow.Field{Name: "value", Type: arrow.BinaryTypes.Binary, Nullable: true, Metadata: metaNoFieldID},
				arrow.Field{Name: "typed_value", Type: extensions.NewUUIDType(), Nullable: true, Metadata: metaNoFieldID},
			), Metadata: metaNoFieldID},
		), Nullable: true, Metadata: metaNoFieldID})

	vt, err := extensions.NewVariantType(s)
	require.NoError(t, err)

	arrSchema := arrow.NewSchema([]arrow.Field{
		{Name: "variant_col", Type: vt, Nullable: true, Metadata: metaNoFieldID},
		{Name: "id", Type: arrow.PrimitiveTypes.Int64, Nullable: false, Metadata: metaNoFieldID},
	}, nil)

	sc, err := pqarrow.ToParquet(arrSchema, nil, pqarrow.DefaultWriterProps())
	require.NoError(t, err)

	// the equivalent shredded variant parquet schema looks like this:
	// repeated group field_id=-1 schema {
	//   optional group field_id=-1 variant_col (Variant) {
	//     required byte_array field_id=-1 metadata;
	//     optional byte_array field_id=-1 value;
	//     optional group field_id=-1 typed_value {
	//       required group field_id=-1 tsmicro {
	//         optional byte_array field_id=-1 value;
	//         optional int64 field_id=-1 typed_value (Timestamp(isAdjustedToUTC=true, timeUnit=microseconds, is_from_converted_type=false, force_set_converted_type=true));
	//       }
	//       required group field_id=-1 strval {
	//         optional byte_array field_id=-1 value;
	//         optional byte_array field_id=-1 typed_value (String);
	//       }
	//       required group field_id=-1 bool {
	//         optional byte_array field_id=-1 value;
	//         optional boolean field_id=-1 typed_value;
	//       }
	//       required group field_id=-1 uuid {
	//         optional byte_array field_id=-1 value;
	//         optional fixed_len_byte_array field_id=-1 typed_value (UUID);
	//       }
	//     }
	//   }
	//   required int64 field_id=-1 id (Int(bitWidth=64, isSigned=true));
	// }

	expected := schema.NewSchema(schema.MustGroup(schema.NewGroupNode("schema",
		parquet.Repetitions.Repeated, schema.FieldList{
			schema.Must(schema.NewGroupNodeLogical("variant_col", parquet.Repetitions.Optional, schema.FieldList{
				schema.MustPrimitive(schema.NewPrimitiveNode("metadata", parquet.Repetitions.Required, parquet.Types.ByteArray, -1, -1)),
				schema.MustPrimitive(schema.NewPrimitiveNode("value", parquet.Repetitions.Optional, parquet.Types.ByteArray, -1, -1)),
				schema.MustGroup(schema.NewGroupNode("typed_value", parquet.Repetitions.Optional, schema.FieldList{
					schema.MustGroup(schema.NewGroupNode("tsmicro", parquet.Repetitions.Required, schema.FieldList{
						schema.MustPrimitive(schema.NewPrimitiveNode("value", parquet.Repetitions.Optional, parquet.Types.ByteArray, -1, -1)),
						schema.MustPrimitive(schema.NewPrimitiveNodeLogical("typed_value", parquet.Repetitions.Optional, schema.NewTimestampLogicalTypeWithOpts(
							schema.WithTSTimeUnitType(schema.TimeUnitMicros), schema.WithTSIsAdjustedToUTC(), schema.WithTSForceConverted(),
						), parquet.Types.Int64, -1, -1)),
					}, -1)),
					schema.MustGroup(schema.NewGroupNode("strval", parquet.Repetitions.Required, schema.FieldList{
						schema.MustPrimitive(schema.NewPrimitiveNode("value", parquet.Repetitions.Optional, parquet.Types.ByteArray, -1, -1)),
						schema.MustPrimitive(schema.NewPrimitiveNodeLogical("typed_value", parquet.Repetitions.Optional,
							schema.StringLogicalType{}, parquet.Types.ByteArray, -1, -1)),
					}, -1)),
					schema.MustGroup(schema.NewGroupNode("bool", parquet.Repetitions.Required, schema.FieldList{
						schema.MustPrimitive(schema.NewPrimitiveNode("value", parquet.Repetitions.Optional, parquet.Types.ByteArray, -1, -1)),
						schema.MustPrimitive(schema.NewPrimitiveNode("typed_value", parquet.Repetitions.Optional,
							parquet.Types.Boolean, -1, -1)),
					}, -1)),
					schema.MustGroup(schema.NewGroupNode("uuid", parquet.Repetitions.Required, schema.FieldList{
						schema.MustPrimitive(schema.NewPrimitiveNode("value", parquet.Repetitions.Optional, parquet.Types.ByteArray, -1, -1)),
						schema.MustPrimitive(schema.NewPrimitiveNodeLogical("typed_value", parquet.Repetitions.Optional,
							schema.UUIDLogicalType{}, parquet.Types.FixedLenByteArray, 16, -1)),
					}, -1)),
				}, -1)),
			}, schema.VariantLogicalType{}, -1)),
			schema.MustPrimitive(schema.NewPrimitiveNodeLogical("id", parquet.Repetitions.Required,
				schema.NewIntLogicalType(64, true), parquet.Types.Int64, -1, -1)),
		}, -1)))

	assert.True(t, sc.Equals(expected), "expected: %s\ngot: %s", expected, sc)

	arrsc, err := pqarrow.FromParquet(sc, nil, metadata.KeyValueMetadata{})
	require.NoError(t, err)

	assert.True(t, arrSchema.Equal(arrsc), "expected: %s\ngot: %s", arrSchema, arrsc)
}
