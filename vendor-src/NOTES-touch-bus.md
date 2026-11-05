# PCLM10 (OPPO Reno Ace, SM8150) — Synaptics S3706 touch: bus, GPIO, power, identification

Read-only analysis of the saved vendor sources. Every claim is either quoted from a file
(path:line) or explicitly marked **does not resolve**. Nothing was taken from board photos
or from the earlier hardware sweep unless said so.

Sources used:
- `dtb/android-merged.dts` — merged base DTB (authoritative for base-tree phandles).
- `dtb/dtbo.bin.01.dts` — DT-BO overlay (where the touch node actually lives).
- `dtb/boot.bin.01.dts` — cross-check of the boot DTB.
- `touch/`, `i2c/`, `pinctrl/`, `power/`, `soc/` driver sources.

How the overlay was decoded: in the decompiled DTBO every reference into the base tree
appears as `<0xffffffff>`; the real target is recorded in `__fixups__` as
`label = "<path>:<node>:<byte-offset>"`. All base-tree phandles below were resolved that
way, not guessed.

---

## 1. The touch node

The touch node exists **only** in the overlay: `dtb/dtbo.bin.01.dts:6878` `fragment@63`.
Its `target = <0xffffffff>` (line 6879) is decompiler noise; the real target is given by
`__fixups__` line 8203 under the label `qupv3_se17_i2c`:

```
qupv3_se17_i2c = "/fragment@63:target:0\0..."
```

and `__symbols__` (`android-merged.dts:24384`) gives
`qupv3_se17_i2c = "/soc/i2c@0xc80000"`.

Full node, `dtb/dtbo.bin.01.dts:6881-6921` (verbatim):

```dts
		__overlay__ {
			status = "okay";

			synaptics19081@20 {
				compatible = "synaptics-s3706";
				reg = <0x20>;
				chip-name = "S3706";
				interrupt-parent = <0xffffffff>;
				interrupts = <0x7a 0x00>;
				vdd_2v8-supply = <0xffffffff>;
				enable1v8_gpio = <0x63 0x05 0x01>;
				vdd_2v8_volt = <0x2dc6c0>;
				irq-gpio = <0xffffffff 0x7a 0x2008>;
				reset-gpio = <0xffffffff 0x36 0x01>;
				pinctrl-names = "default";
				pinctrl-0 = <0xffffffff 0xffffffff>;
				touchpanel,max-num-support = <0x0a>;
				touchpanel,tx-rx-num = <0x0f 0x22>;
				touchpanel,panel-coords = <0x438 0x960>;
				touchpanel,display-coords = <0x438 0x960>;
				touchpanel,touchmajor-limit = <0x00 0x36>;
				tp_type = <0x08>;
				platform_support_project = <0x4a89>;
				platform_support_project_dir = <0x4a89>;
				platform_support_project_commandline = "default_commandline";
				black_gesture_support;
				fw_edge_limit_support;
				fw_corner_limit_support;
				charger_pump_support;
				game_switch_support;
				face_detect_support;
				smart_gesture_support;
				pressure_report_support;
				fw_update_app_support;
				fingerprint_underscreen_support;
				rt155_fdreplace_rt59_support;
				report_120hz_support;
				report_point_first_support;
				touchpanel,button-type = <0x04>;
				touchpanel.button-TRx = <0x00 0x00>;
			};
		};
```

Notes on the node:
- I2C address `0x20`; driver binding name `synaptics-s3706`
  (`touch/synaptics_s3706.h:40` `#define TPD_DEVICE "synaptics-s3706"`, used by the
  of_match/id tables at `touch/synaptics_drivers_s3706.c:5906-5914`).
- `0x4a89` = 19081 (the node name `synaptics19081`), the Oplus project tag. It is only
  parsed into `ts->panel_data.platform_support_project`
  (`touch/touchpanel_common_driver.c:6515-6546`) and is **not** used as a probe gate.
- There is **no** `vdd_5v0-supply`, no `vcc_1v8-supply`, and no `clock`/`clocks` property
  in this node. `vdd_5v0` does not appear anywhere in `vendor-src` (grep: no matches).
- The second `fragment@63` hit (`dtbo.bin.01.dts:9246`) is only the `__local_fixups__`
  entry `enable1v8_gpio = <0x00>`, i.e. the `0x63` phandle is overlay-local (see §3).

## 2. The bus: SE17 / `i2c@0xc80000`, TLMM gpio55 + gpio56 (SOUTH tile)

Parent node, `dtb/android-merged.dts:20493-20508` (verbatim):

```dts
		i2c@0xc80000 {
			compatible = "qcom,i2c-geni";
			reg = <0xc80000 0x4000>;
			interrupts = <0x00 0x175 0x00>;
			#address-cells = <0x01>;
			#size-cells = <0x00>;
			clock-names = "se-clk\0m-ahb\0s-ahb";
			clocks = <0x1b 0x6d 0x1b 0x7d 0x1b 0x7e>;
			dmas = <0x289 0x00 0x00 0x03 0x40 0x00 0x289 0x01 0x00 0x03 0x40 0x00>;
			dma-names = "tx\0rx";
			pinctrl-names = "default\0sleep";
			pinctrl-0 = <0x29d>;
			pinctrl-1 = <0x29e>;
			qcom,wrapper-core = <0x275>;
			phandle = <0x571>;
		};
```

- No `status` property → enabled; the overlay additionally sets `status = "okay"`.
- `phandle 0x29d` = `qupv3_se17_i2c_active`, `android-merged.dts:8239-8252`:

```dts
				qupv3_se17_i2c_active {
					phandle = <0x29d>;

					mux {
						pins = "gpio55\0gpio56";
						function = "qup17";
					};

					config {
						pins = "gpio55\0gpio56";
						drive-strength = <0x04>;
						bias-disable;
					};
				};
```

- `phandle 0x29e` = `qupv3_se17_i2c_sleep` (lines 8254-8267): same pins, `function =
  "gpio"`, `drive-strength = <0x04>`, `bias-pull-up` (the bus lines are held as pulled-up
  GPIOs while the SE is asleep).
- Pin mux capability, `pinctrl/pinctrl-sm8150.c:1668` and `:1670`:

```c
	[55] = PINGROUP(55, SOUTH, qup17, qup19, qup11, qup12, qup13, qup14, qup15, qup16),
	[56] = PINGROUP(56, SOUTH, qup17, qup19, qdss_cti, qup11, qup12, qup13, qup14, qup15),
```

  (gpio54 = `PINGROUP(54, SOUTH, fido_rx, ...)`, line 1667; gpio122 = `PINGROUP(122,
  SOUTH, spi_cs1, ...)`, line 1775 — both only usable as plain `gpio` for this device.)
- Tile + register offsets, `pinctrl/pinctrl-sm8150.c:28-37,56-58`:

```c
#define NORTH	0x00900000
#define SOUTH	0x00D00000
...
#define REG_SIZE 0x1000
...
		.ctl_reg = base + REG_SIZE * id,		\
		.io_reg = base + 0x4 + REG_SIZE * id,	\
		.intr_cfg_reg = base + 0x8 + REG_SIZE * id,	\
```

  These tile constants are offsets from the TLMM base; `pinctrl/pinctrl-msm.c:2132`
  `pctrl->regs = devm_ioremap_resource(&pdev->dev, res);` maps the DT node
  `pinctrl@03000000` with `reg = <0x3000000 0xdc2000 ...>` (`android-merged.dts:6274`),
  and every group register offset is added to that base. Therefore:

| pin | tile | tile base | `ctl_reg` absolute |
|---|---|---|---|
| gpio54 (TP reset) | SOUTH | 0x03D00000 | **0x03D36000** |
| gpio55 (SDA) | SOUTH | 0x03D00000 | **0x03D37000** |
| gpio56 (SCL) | SOUTH | 0x03D00000 | **0x03D38000** |
| gpio122 (TP IRQ) | SOUTH | 0x03D00000 | **0x03D7A000** |

  (Tile assignment is *not* monotonic in this SoC: gpio83/84 and 88/89 are NORTH, gpio87
  is EAST, gpio114/115 and 121-123 are SOUTH.)
- SE wrapper / clocks / DMA resolved: `<0x275>` = `qcom,qupv3_2_geni_se@cc0000`
  (`android-merged.dts:20424`, `compatible = "qcom,qupv3-geni-se"`, `reg = <0xcc0000
  0x6000>`); `<0x1b>` = `qcom,gcc` (`android-merged.dts:3015`, `compatible =
  "qcom,gcc-sm8150-v2"`, `#clock-cells = <1>`); `<0x289>` = the GPI DMA top at
  `0xc00000` (`android-merged.dts:5983`). The SE clock cell `0x6d` (=109) cannot be
  mapped to a name: no `dt-bindings/clock/qcom,gcc-sm8150.h` header exists in
  `vendor-src` — **does not resolve**.

**Verdict on the earlier gpio55/56 hypothesis: correct.** gpio55/gpio56 are the SDA/SCL of
SE17 (`i2c@0xc80000`), muxed with function `qup17`, which is exactly the parent the touch
overlay attaches to. The `sleep` state re-muxes the same two pins to `gpio` with pull-ups,
which is why bit-banging them is possible when the SE is idle.

## 3. What the enable / reset / interrupt phandles resolve to

All three `0xffffffff` phandles in the touch node are base-tree references to the TLMM
gpio-controller. Confirmed by the `tlmm` entry of `__fixups__`
(`dtb/dtbo.bin.01.dts:8095`), which contains, among many others:

```
/fragment@63/__overlay__/synaptics19081@20:interrupt-parent:0
\0/fragment@63/__overlay__/synaptics19081@20:irq-gpio:0
\0/fragment@63/__overlay__/synaptics19081@20:reset-gpio:0
```

and `__symbols__` (`android-merged.dts:23319`) `tlmm = "/soc/pinctrl@03000000"`.

| property | resolved meaning |
|---|---|
| `interrupt-parent` | `/soc/pinctrl@03000000` (TLMM interrupt controller) |
| `interrupts = <0x7a 0x00>` | TLMM gpio **122**, type cell `0` → `*type = fwspec->param[1] & IRQ_TYPE_SENSE_MASK` = `IRQ_TYPE_NONE` (`pinctrl/pinctrl-msm.c:989`) |
| `irq-gpio = <&tlmm 0x7a 0x2008>` | gpio **122**, flags `0x2008` |
| `reset-gpio = <&tlmm 0x36 0x01>` | gpio **54**, flags `0x01` |
| `pinctrl-0 = <0xffffffff 0xffffffff>` | fixups give byte offsets `:0` and `:4` → two phandles, `&ts_int_active` + `&ts_reset_active` |

`ts_int_active` / `ts_reset_active`, `dtb/android-merged.dts:6936-6967` (verbatim):

```dts
				ts_int_active {
					phandle = <0x38f>;

					mux {
						pins = "gpio122";
						function = "gpio";
					};

					config {
						pins = "gpio122";
						drive-strength = <0x08>;
						bias-pull-up;
					};
				};
...
				ts_reset_active {
					phandle = <0x390>;

					mux {
						pins = "gpio54";
						function = "gpio";
					};

					config {
						pins = "gpio54";
						drive-strength = <0x08>;
						bias-disable;
					};
				};
```

The pull-up on gpio122 corroborates an idle-high / asserted-low interrupt.

### The 1.8 V enable is a PMIC GPIO, not a TLMM GPIO

`enable1v8_gpio = <0x63 0x05 0x01>` — `0x63` is **overlay-local** (it is in
`__local_fixups__`, `dtbo.bin.01.dts:9246`, so no base-tree label is involved). It is
defined at `dtb/dtbo.bin.01.dts:1433` inside `fragment@4` →
`qcom,pm8150l@4` → `pinctrl@c000` (`dtbo.bin.01.dts:1386-1433`, verbatim excerpt):

```dts
			qcom,pm8150l@4 {
				compatible = "qcom,spmi-pmic";
				reg = <0x04 0x00>;
...
				pinctrl@c000 {
					compatible = "qcom,spmi-gpio";
					reg = <0xc000 0xc00>;
					interrupt-names = "pm8150l_gpio1\0pm8150l_gpio2\0pm8150l_gpio3\0pm8150l_gpio4\0pm8150l_gpio5\0pm8150l_gpio6\0pm8150l_gpio8\0pm8150l_gpio9\0pm8150l_gpio10\0pm8150l_gpio11\0pm8150l_gpio12";
					gpio-controller;
					#gpio-cells = <0x02>;
					qcom,gpios-disallowed = <0x07>;
					phandle = <0x63>;
```

`fragment@4:target:0` is listed under the `spmi_bus` label (`dtbo.bin.01.dts:8092`), and
`__symbols__` (`android-merged.dts:23235`) gives `spmi_bus = "/soc/qcom,spmi@c440000"`.
So `0x63` = **the PM8150L (SPMI slave ID 4) GPIO block at SPMI address 0xc000**, and the
first cell `0x05` is its *physical* GPIO number 5 — `pinctrl/pinctrl-spmi-gpio.c:110`
`#define PMIC_GPIO_PHYSICAL_OFFSET 1`, `:1152` `pad->gpio_idx = i +
PMIC_GPIO_PHYSICAL_OFFSET`, and `pmic_gpio_of_xlate()` (`:763-789`) maps the DT cell back
to the internal pin index (`return i;`). Physical GPIO_07 is excluded
(`qcom,gpios-disallowed = <0x07>`), consistent with the interrupt-names list that skips
gpio7. The third cell `0x01` is the flags cell; `of_get_named_gpio()` is called with
`flags == NULL` (`touch/touchpanel_common_driver.c:6723`), so it is ignored.

- Neither base tree contains any PMIC pinctrl node: `android-merged.dts` has only
  `qcom,pm8150l-debug@4/@5` placeholders (lines 3203-3243) and no `pinctrl@c000`;
  `boot.bin.01.dts` has the SPMI bus `qcom,spmi@c440000` (line 3178) but no
  `pinctrl@c000` / `qcom,pm8150l@`. The PMIC GPIO controller comes **only** from the DTBO.
- The overlay also defines a pinctrl state named `touchpanel_1v8_enable/enable_1v8_gpio`
  (`dtbo.bin.01.dts:1508-1519`, `pins = "gpio5"`, `function = "normal"`,
  `bias-disable`, `power-source = <0x00>`, `output-low`, `qcom,drive-strength = <0x03>`,
  `drive-push-pull`, `phandle = <0xde>`). Phandle `0xde` is referenced **nowhere** in the
  overlay (grep for `0xde` matches only its own definition), so this state is dead code;
  the touch node's `pinctrl-0` is only `&ts_int_active &ts_reset_active`.

## 4. Vendor power-up sequence, timings, and identification

### Power-on order (probe path)

`touch/touchpanel_common_driver.c:7492-7512` — `preconfig_power_control()` →
`init_power_control()` → `reconfig_power_control()` → `ts->ts_ops->power_control(..., true)`
→ I2C functionality check (`:7515`) → input device → FTM check →
`get_chip_info` (`:7596`) → `fw_check` (`:7610`) → `mode_switch(MODE_NORMAL, true)`
(`:7626`) → IRQ registration.

`touch/synaptics_drivers_s3706.c:1222-1252` (verbatim):

```c
static int synaptics_power_control(void *chip_data, bool enable)
{
        int ret = 0;
        struct chip_data_s3706 *chip_info = (struct chip_data_s3706 *)chip_data;

        if (true == enable) {
                ret = tp_powercontrol_2v8(chip_info->hw_res, true);
                if (ret) {
                        return -1;
                }
                ret = tp_powercontrol_1v8(chip_info->hw_res, true);
                if (ret) {
                        return -1;
                }
                msleep(POWEWRUP_TO_RESET_TIME);
                synaptics_resetgpio_set(chip_info->hw_res, true);
                msleep(RESET_TO_NORMAL_TIME);
        } else {
                ret = tp_powercontrol_1v8(chip_info->hw_res, false);
                ...
                ret = tp_powercontrol_2v8(chip_info->hw_res, false);
                ...
                synaptics_resetgpio_set(chip_info->hw_res, false);
        }
```

Timings, `touch/synaptics_s3706.h:38-39`:

```c
#define RESET_TO_NORMAL_TIME 80        /*Sleep time after reset*/
#define POWEWRUP_TO_RESET_TIME 10
```

So the vendor sequence is:

1. `vdd_2v8` regulator ON (`tp_powercontrol_2v8`, `touchpanel_common_driver.c:7128`) —
   no `enable2v8_gpio` exists in this DT, so that branch is skipped.
2. 1.8 V ON (`tp_powercontrol_1v8`, `:7084`): `regulator_enable(vcc_1v8)` if present
   (it is **not** present here), then `gpio_direction_output(enable1v8_gpio, 1)` —
   i.e. PM8150L GPIO5 driven **HIGH** (`:7098-7105`).
3. `msleep(10)` (`POWEWRUP_TO_RESET_TIME`).
4. Reset released: `gpio_direction_output(reset_gpio, true)` → TLMM gpio54 driven
   **HIGH** (`synaptics_drivers_s3706.c:527-535`; the DT's `0x01` active-low cell is
   discarded because `of_get_named_gpio()` is used, `touchpanel_common_driver.c:6652`).
5. `msleep(80)` (`RESET_TO_NORMAL_TIME`).

Power-down is the reverse: 1v8 off → 2v8 off → reset low. The other reset helper,
`synaptics_reset()` (`synaptics_drivers_s3706.c:540-551`), does reset-low →
`msleep(10)` → reset-high → `msleep(80)`.

Regulator setup at probe, `touchpanel_common_driver.c:7022-7082`:
`regulator_get(dev, "vcc_1v8")` then `regulator_set_voltage(..., 1800000, 1800000)` and
`regulator_set_load(..., 200000)`; `regulator_get(dev, "vdd_2v8")` then
`regulator_set_voltage(vdd_2v8, ts->hw_res.vdd_volt, ts->hw_res.vdd_volt)` with a
3100000 µV fallback, `regulator_set_load(..., 200000)`. `vdd_volt` comes from
`vdd_2v8_volt` (`:6630`). Both `regulator_get()` failures are non-fatal
(`IS_ERR_OR_NULL` → log only).

Interrupt, `touch/touchpanel_common_driver.c:6637` and `:7279-7307`. `TPD_USE_EINT` **is
defined** (`touch/touchpanel_common.h:41`), so the driver derives the IRQ line itself:

```c
    ts->hw_res.irq_gpio = of_get_named_gpio_flags(np, "irq-gpio", 0, &(ts->irq_flags));
...
        if(ts->irq <= 0) {
            ts->irq = gpio_to_irq(ts->hw_res.irq_gpio);
...
            } else {
                ts->client->irq = gpio_to_irq(ts->hw_res.irq_gpio);
...
        ret = request_threaded_irq(ts->irq, NULL,
                                   tp_irq_thread_fn,
                                   ts->irq_flags | IRQF_ONESHOT,
                                   TPD_DEVICE, ts);
```

`ts->irq_flags` is the DT's second cell, `0x2008`. Under the standard Linux IRQ-flag
constants that is `IRQF_TRIGGER_LOW (0x8) | IRQF_ONESHOT (0x2000)`; `linux/interrupt.h`
itself is not in `vendor-src`, so that decode is stated from the kernel ABI, not from a
file here. `gpio_to_irq(122)` goes through the TLMM gpio irq domain, so the effective
trigger comes from this flags cell — the node's `interrupts = <0x7a 0x00>` type cell
(NONE) is not what sets the trigger. Both spellings point at the same pin, gpio122.

### Identification: there is no product-ID gate

- `PRODUCT_ID_SIZE`, `product_id_string[]` and `product_id[]`/`cstmr_product_id[]` are
  declared (`touch/synaptics_s3706.h:71, 342, 737-738`) but **never used** by any `.c`
  file in `vendor-src` (grep for `product`/`TCM` in the whole tree hits only those
  declarations). No accepted-ID list exists anywhere.
- What the driver actually reads at start-up is the RMI4 page-select + query-base dance,
  `synaptics_get_chip_info()` (`synaptics_drivers_s3706.c:176`): `touch_i2c_write_byte(
  client, 0xff, page)` then `touch_i2c_read_block(client, 0xDD, 4, buf)` (F12 bases,
  page 0), `0xE3` (F01 bases), `0xE9` (F34 bases); page 4 + `0xE9` → F51; page 1 + `0xE9`
  → F54. The returned values are never validated against a table.
- `synaptics_fw_check()` (`:350-391`) reads `F12_2D_CTRL08` (4 bytes → max_x/max_y) and
  `F01_RMI_DATA_BASE`, masking bit `0x40` (bootloader mode). It returns `FW_ABNORMAL`
  **only** if `max_x_ic == 0 || max_y_ic == 0 || (F01 cmd & 0x40) == 0x40`
  (`:374-377`); otherwise `FW_NORMAL`. So "acceptance" = "the query registers answered".
- The closest thing to a product ID is `synaptics_rmi4_fwu_init()`
  (`:3608-3663`): it reads 3 bytes at `f01_query_base_addr + 18` (i.e. F01 query + 0x12,
  the RMI4 Product ID field) into `build_id[]` and computes
  `firmware_id = build_id[0] + build_id[1]*0x100 + build_id[2]*0x10000`. That value is
  used only to decide whether to reflash: `device_fw_id = rmi4_data->firmware_id`
  (`:4026`) vs. `fwu_get_image_firmware_id()` (`:3958-3995`, which takes the ID from the
  image header or from digits in the FW file name) — `if (image_fw_id != device_fw_id)
  flash_area = UI_FIRMWARE;` (`:4037-4040`). A second comparison byte-for-byte compares
  the config block (`:4054-4063`).
- `synaptics_get_fw_id()` (`:296-303`) selects page 0 and reads 4 bytes at
  `F34_FLASH_CTRL_BASE`, big-endian, as `CURRENT_FIRMWARE_ID`.
- `CMD_V7_SENSOR_ID` is *defined* in `enum v7_flash_command`
  (`touch/synaptics_s3706.h:195-203`) but **never used** anywhere in the sources.
- Exact I2C transaction framing cannot be shown: the `touch_i2c_read_block()` /
  `touch_i2c_write_byte()` helpers live in `../synaptics_common.c` + `synaptics_common.h`
  (included at `synaptics_s3706.h:17`), which are **not present in `vendor-src`** —
  **does not resolve**. From the calls alone the protocol is: single write to register
  `0xFF` = page select, and `reg, len` block reads at the addresses above, to slave
  address `0x20` on SE17.

## 5. Supply → RPMh mapping

`vdd_2v8-supply = <0xffffffff>` resolves through the `__fixups__` label `pm8150_l17`
(`dtb/dtbo.bin.01.dts:8122`, which contains
`/fragment@63/__overlay__/synaptics19081@20:vdd_2v8-supply:0`), and
`__symbols__` (`android-merged.dts:23783`) gives
`pm8150_l17 = "/soc/rpmh-regulator-ldoa17/regulator-pm8150-l17"`.

Target node, `dtb/android-merged.dts:12583-12600` (verbatim):

```dts
		rpmh-regulator-ldoa17 {
			compatible = "qcom,rpmh-vrm-regulator";
			mboxes = <0x53 0x00>;
			qcom,resource-name = "ldoa17";
			qcom,regulator-type = "pmic5-ldo";
			qcom,supported-modes = <0x02 0x04>;
			qcom,mode-threshold-currents = <0x00 0x01>;

			regulator-pm8150-l17 {
				regulator-name = "pm8150_l17";
				qcom,set = <0x03>;
				regulator-min-microvolt = <0x2b9440>;
				regulator-max-microvolt = <0x2de600>;
				qcom,init-voltage = <0x2b9440>;
				qcom,init-mode = <0x02>;
				phandle = <0x495>;
			};
		};
```

- `0x2b9440` = 2 856 000 µV, `0x2de600` = 3 008 000 µV. The touch's
  `vdd_2v8_volt = <0x2dc6c0>` = **3 000 000 µV (3.0 V)**, inside that range — so the
  "2.8 V" name is only the rail's nominal/init value; the driver actually votes 3.0 V.
- Phandle `0x495` is referenced nowhere else in `android-merged.dts` (grep for `0x495`
  matches only its definition at line 12598), i.e. **L17 has no other consumer** in this
  tree; the touch overlay is its only user.
- `qcom,set` is decoded into exactly two flags, `power/rpmh-regulator.c:1779-1780`
  `vreg->set_active = !!(set & RPMH_REGULATOR_SET_ACTIVE); vreg->set_sleep = !!(set &
  RPMH_REGULATOR_SET_SLEEP);`. The bit values come from a header that is **not in
  `vendor-src`**, so `0x03`'s exact meaning **does not resolve here**; by upstream
  convention it is ACTIVE|SLEEP, i.e. votable in both the active/wakeup set and the
  sleep set.
- `qcom,supported-modes = <0x02 0x04>` / `qcom,init-mode = <0x02>` are **indices into the
  driver's mode map**, not raw PMIC register values
  (`power/rpmh-regulator.c:1580-1604` maps `qcom,init-mode` through
  `rpmh_regulator_mode_map[hw_type]`). For `pmic5-ldo` that map
  (`:370-384`) defines only `RPMH_REGULATOR_MODE_RET` → raw 3,
  `RPMH_REGULATOR_MODE_LPM` → raw 4, `RPMH_REGULATOR_MODE_HPM` → raw 7
  (`:293-295`). The numeric values of the DT-facing enum
  `RPMH_REGULATOR_MODE_{OFF,RET,LPM,AUTO,HPM}` live in
  `dt-bindings/regulator/qcom,rpmh-regulator.h`, which is **not in `vendor-src`** — so the
  exact meaning of `0x02`/`0x04` **does not resolve here**; by upstream convention they are
  LPM and HPM, and `qcom,mode-threshold-currents = <0x00 0x01>` (0 mA, 1 mA) matches a
  two-mode LDO. `mboxes = <0x53 0x00>` is the RPMh mailbox client (a base-tree phandle).

### How a vote becomes an RPMh TCS command

`power/rpmh-regulator.c`:
- The register layout is by index, `:94-108`, with the comment at `:92`
  "Register addresses are calculated as: base_addr + sizeof(u32) * reg_index":

```c
	RPMH_REGULATOR_REG_VRM_VOLTAGE		= 0,
	RPMH_REGULATOR_REG_VRM_ENABLE		= 1,
	RPMH_REGULATOR_REG_VRM_MODE		= 2,
	RPMH_REGULATOR_REG_VRM_HEADROOM		= 3,
```

- The command is built at `:757-758` `cmd[j].addr = aggr_vreg->addr + i * 4;
  cmd[j].data = req_active.reg[i];` and sent with `rpmh_write_async(...,
  RPMH_ACTIVE_ONLY_STATE / RPMH_WAKE_ONLY_STATE / RPMH_SLEEP_STATE, cmd, j)`
  (`:730`, `:776`, `:787-789`); a rising value forces `wait_for_ack` (`:766-768`).
- Values are plain, not encoded: voltage is written as **millivolts**
  (`:967` `mv = DIV_ROUND_UP(min_uv, 1000);` → `:977`
  `rpmh_regulator_set_reg(vreg, RPMH_REGULATOR_REG_VRM_VOLTAGE, mv)`; `:1007`
  `uv = vreg->req.reg[RPMH_REGULATOR_REG_VRM_VOLTAGE] * 1000`), enable is 0/1
  (`:897`, `:933`), mode is the raw PMIC mode value, headroom is capped at 511 mV
  (`:126-127`).

So for a VRM resource whose cmd_db base is `A`: `A+0x00` = voltage in mV, `A+0x04` =
enable, `A+0x08` = mode, `A+0x0c` = headroom. For `pm8150_l17` at 3.0 V that is a vote of
`3000` into `A+0x00` and `1` into `A+0x04`.

### The 1.8 V and 5 V side

- **1.8 V is not a regulator here at all.** The touch node has no `vcc_1v8-supply`, so
  `regulator_get(ts->dev, "vcc_1v8")` fails and `init_power_control()` only logs it
  (`touchpanel_common_driver.c:7027-7029`); `tp_powercontrol_1v8()` then skips the
  regulator branch and only drives the PMIC GPIO high (`:7089-7105`). The 1.8 V domain is
  switched by **PM8150L SPMI-GPIO5** used as an enable / load-switch control.
- **`vdd_5v0` does not exist anywhere in `vendor-src`** (grep: zero matches) — the touch
  node has no 5 V supply property and no driver code asks for one.
- The RPMh address of `ldoa17` is **not** in these sources: `rpmh-regulator.c:1890`
  `aggr_vreg->addr = cmd_db_get_addr(aggr_vreg->resource_name);`, and `soc/cmd-db.c:153`
  reads it out of a runtime table whose location is discovered from the DT node
  `qcom,cmd-db@c3f000c` (`android-merged.dts:4338-4342`, `reg = <0xc3f000c 0x08>`), whose
  two words are the table's start address and length (`soc/cmd-db.c:363-364`). That table
  is written by the bootloader, so **the value `0x41300` can be neither confirmed nor
  refuted from `vendor-src`**. On a running device it is readable from
  `/sys/kernel/debug/cmd_db`, which `cmd-db.c:292` prints as
  `"Address: 0x%05x, id: %s"`.

## 6. What does not resolve from these sources

1. The SE17 `se-clk` clock cell `0x6d` → name: no `dt-bindings/clock/qcom,gcc-sm8150.h`
   in `vendor-src`.
2. The meaning of the DT mode indices `0x02` / `0x04` for `pmic5-ldo`, and of
   `qcom,set = <0x03>`: `dt-bindings/regulator/qcom,rpmh-regulator.h` and the
   `RPMH_REGULATOR_SET_*` header are absent.
3. The exact I2C byte framing of `touch_i2c_read_block()` / `touch_i2c_write_byte()`:
   `synaptics_common.c` / `synaptics_common.h` (included at `synaptics_s3706.h:17`) are
   not in `vendor-src`.
4. The RPMh address of `ldoa17` (`0x41300`): it comes from the bootloader's cmd_db table,
   which is not in `vendor-src`.
5. The numeric `IRQF_*` decode of the `irq-gpio` flags cell `0x2008`: `linux/interrupt.h`
   is not in `vendor-src` (the decode above is stated from the kernel ABI).
6. Whether PM8150L GPIO5 physically feeds a 1.8 V load switch, and what that rail feeds:
   no regulator node and no schematic exists in these sources — the DT only says "drive
   PM8150L GPIO5 high".



---

## 7. pm8150_l17 is shared with the display: the 2.8 V vote is what blanked the panel

Measured on the phone, 2026-11-02, runs `194232`, `195245`, `200024`.

- `dtbo.bin.01.dts:8122`, the `__symbols__` table, resolves `pm8150_l17` to **two** targets:
  `/fragment@37/__overlay__/qcom,dsi-display-primary:lab-supply` and
  `/fragment@63/__overlay__/synaptics19081@20:vdd_2v8-supply`.
  The touch's 2.8 V and the panel's analog (LAB) supply are the same regulator.
- `android-merged.dts:12586`, `rpmh-regulator-ldoa17`: `qcom,supported-modes = <0x02 0x04>`,
  `qcom,init-mode = <0x02>`, `regulator-min-microvolt = <0x2b9440>` (2.856 V),
  `regulator-max-microvolt = <0x2de600>` (3.008 V). Upstream's mode numbers are AUTO = 0x02 and
  HPM = 0x04; the value the first version of the vote sent, 7, is not a mode this resource has.
- On the phone: `194232` and `195245` drew the Apple logo and then went black, while everything
  else booted normally (WindowServer up, `backlight ready`, digitizer attached, identical to a run
  that shows the home screen). The same boot with the touch driver left out, `200024`, reaches the
  home screen and the user sees it. The only difference is the touch driver, and the one thing it
  writes that can reach the panel is this vote.
- What follows for the port: the rail is **already on**, at 2.856-3.008 V, because the display runs
  from it -- which is exactly the 2.8 V the touch wants. The touch does not need to ask. The driver
  now leaves it alone unless `touch_2v8=1`, and when asked it sends mode 0x02, the tree's own
  init-mode, rather than 7.

## 8. What the vendor reads where, and what the chip answers

- `synaptics_get_chip_info` (`synaptics_drivers_s3706.c:176`) selects page 0 with `0xff <- 0x00`,
  then reads four bytes at 0xdd / 0xe3 / 0xe9 and calls them the query / command / control / data
  bases of F12 / F01 / F34. On this chip those reads are `49 00 13 08`, `2a 21 0d 06`,
  `22 00 0c 00`.
- Two of those numbers are confirmed by behaviour rather than by the table, which is what matters.
  0x06, the F01 "data" base, is the device-status byte plus three interrupt-status bytes: it reads
  `81 22 00 00`, and the second byte was later seen at `20` and once at `04` -- which are exactly
  the vendor's `IRQ_FACE_STATE`/`IRQ_FW_HEALTH` bit (`synaptics_drivers_s3706.c:473`) and
  `IRQ_TOUCH` bit (`:462`). And 0x0d, the F01 "control" base, holds `0x7f` at 0x0e, which is what
  the vendor's `enable_interrupts` tests for before it believes the interrupts are on.
- `synaptics_fw_check` (`:350`) reads four bytes at `F12_2D_CTRL08`, which is `F12_2D_CTRL_BASE`
  = **0x13**, and takes bytes 0-1 as max x and 2-3 as max y; it calls the chip abnormal if either
  is zero or if bit 6 of the F01 device status (flash-loader mode) is set. The phone answers
  `max x 1079, max y 2399` -- this panel's real 1080x2400 -- and 0x81 with bit 6 clear. So the
  F12 control base is real and the vendor's own health check passes: the firmware is running.
- The objects: `synaptics_get_touch_points` (`:65`) reads the object attention word as a 16-bit
  read at `F12_2D_DATA15` = `F12_2D_DATA_BASE + 3` = **0x0b** (`:243`,
  `synaptics_s3706.h:827-828`), counts the set bits, and then reads eight bytes per object starting
  at `F12_2D_DATA_BASE` = **0x08**. The 19:42 run watched that word at 0x0b for forty seconds and
  it never moved, while the F01 interrupt byte moved five times, once to `04`, the touch bit.
- That contradiction is why the watch is now a register diff: all 64 bytes of page zero compared
  against a baseline every 100 ms, and whatever moves under a finger is the object data, whatever
  the map is called. The 19:52 run ran that and nothing moved at all -- but the panel was black by
  then, so no hand was on the glass, and it settles nothing. It has to be run again with the
  display up.
