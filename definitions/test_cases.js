const { generate_udf_test } = unit_test_utils;

generate_udf_test("kelvin_to_fahrenheit", [
  {
    inputs: [`CAST(273 AS FLOAT64)`],
    expected_output: [`CAST(31.73000000000004 AS FLOAT64)`],
  },
]);