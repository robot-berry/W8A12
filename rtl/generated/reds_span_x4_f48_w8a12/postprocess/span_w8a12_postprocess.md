# SPAN W8A12 Postprocess LUT Export

Quant plan: `runs\reds_span_quant_plan\reds_span_x4_f48_w8a12_reds_val4\span_w8a12_quant_plan.json`
Activation bits: `12`
Entries: `18`
Header: `rtl\generated\reds_span_x4_f48_w8a12\postprocess\span_w8a12_postprocess.vh`
Manifest: `rtl\generated\reds_span_x4_f48_w8a12\postprocess\span_w8a12_postprocess_manifest.json`
Preview: `rtl\generated\reds_span_x4_f48_w8a12\postprocess\span_w8a12_postprocess_preview.png`
Attention preview: `rtl\generated\reds_span_x4_f48_w8a12\postprocess\span_w8a12_attention_preview.png`

| ID | Name | Kind | Input scale | Output scale | q range |
| --- | --- | --- | --- | --- | --- |
| 0 | `block_1.act1` | `silu` | `0.017505037` | `0.016238293` | `-17..2047` |
| 1 | `block_1.act2` | `silu` | `0.013598887` | `0.0032310027` | `-86..2047` |
| 2 | `block_1.attention` | `span_attention` | `0.0039602136` | `0.00024411261` | `-2047..2047` |
| 3 | `block_2.act1` | `silu` | `0.023791526` | `0.023791526` | `-12..2047` |
| 4 | `block_2.act2` | `silu` | `0.038700666` | `0.0068367533` | `-41..2047` |
| 5 | `block_2.attention` | `span_attention` | `0.0095432075` | `0.00024425989` | `-2047..2047` |
| 6 | `block_3.act1` | `silu` | `0.0074322205` | `0.0028646956` | `-97..2047` |
| 7 | `block_3.act2` | `silu` | `0.0038241157` | `0.0023869232` | `-117..2047` |
| 8 | `block_3.attention` | `span_attention` | `0.0053257309` | `0.00024425087` | `-2047..2047` |
| 9 | `block_4.act1` | `silu` | `0.0059762155` | `0.0028864357` | `-96..2047` |
| 10 | `block_4.act2` | `silu` | `0.0070284773` | `0.0023224419` | `-120..2047` |
| 11 | `block_4.attention` | `span_attention` | `0.0039268844` | `0.00024410225` | `-2047..2047` |
| 12 | `block_5.act1` | `silu` | `0.0055332291` | `0.0031446777` | `-89..2047` |
| 13 | `block_5.act2` | `silu` | `0.0045112222` | `0.0031620539` | `-88..2047` |
| 14 | `block_5.attention` | `span_attention` | `0.0044823494` | `0.00024420931` | `-2047..2047` |
| 15 | `block_6.act1` | `silu` | `0.0023401822` | `0.0020779243` | `-134..2047` |
| 16 | `block_6.act2` | `silu` | `0.0047481298` | `0.0020782738` | `-134..2047` |
| 17 | `block_6.attention` | `span_attention` | `0.0033815214` | `0.00024377875` | `-2047..2047` |
