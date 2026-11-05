# Vendor sources for the OPPO Reno Ace (PCLM10)

The phone's own hardware code, kept here so that every register, power rail and bus rule this port
needs can be read from the vendor's source instead of being rediscovered on the phone. Nothing in
this directory is built into the kernel; it is reference material.

Where it comes from:

- **kernel** — `github.com/oppo-source/android_kernel_oppo_sm8150`, branch
  `oppo/sm8150_s_12.1_oppo_reno10` (the OPPO/OnePlus sm8150 family, which includes the Reno Ace).
- **modules** — `github.com/oppo-source/android_kernel_modules_and_devicetree_oppo_sm8150`, same
  branch. This is where the OPlus touch drivers live.
- **dtb** — the phone's own device tree, decompiled here from the bootloader image (`dtb-out/` in
  the build tree): the boot DT the kernel is started with, and the dtbo overlay that adds the
  touch, the gauge and the charging parts.

Fetched 2026-11-02 with `tools`-less `curl`; the script that did it is
`device-src` history in the session, and every file below was non-empty when fetched.

## power — the charger and the pack gauge

| File | What it answers |
|---|---|
| `power/oplus_bq27541.c`, `.h` | **The pack gauge.** Its standard command map: 0x2C StateOfCharge, 0x08 voltage, 0x14 average current, 0x06 temperature, 0x0A flags, 0x0C nominal capacity. The driver also shows how OPPO tells a BQ27541 from a BQ28Z610 and what it writes at probe. |
| `power/oplus_battery_msm8150.c/.h`, `oplus_battery_msm8150_pro.c/.h` | OPPO's charging stack for this SoC: which parts are polled, the charge current/voltage limits, the JEITA table, and how the gauge and the charger are stitched together. |
| `power/oplus_stm.c/.h` | The VOOC controller (STM8S at 0x26 on the gauge's bus) — the other device on `i2c@0xc94000`. |
| `power/qpnp-smb5.c`, `smb-lib.c/.h` | The PM8150B SMB5 charger driver: every register this port reads, and the stage/status encoding. |
| `power/qpnp-fg-gen4.c`, `battery.c/.h` | The PM8150B's gen4 fuel gauge (disabled in this phone's overlay, kept for reference) and the battery-profile plumbing. |
| `power/rpmh-regulator.c` | **The RPMh regulator vote format**: a VRM resource's registers are `base+0 voltage (mV)`, `base+4 enable`, `base+8 mode` (PMIC5 LDO HPM = 7), `base+0xc headroom`, sent as TCS commands. This is how `pm8150_l17` (the touch's 2.8 V) is switched — the boot loader's command database names it `ldoa17`, entry address `0x00041300`. |
| `power/qcom_spmi-regulator.c` | The directly writable SPMI regulators, for comparison. |

## touch — the S3706 and the OPlus touch framework

| File | What it answers |
|---|---|
| `touch/synaptics_drivers_s3706.c`, `synaptics_s3706.h` | **The touch driver for this panel** (`compatible = "synaptics-s3706"`). The power-up order (`tp_powercontrol_1v8()` → reset low → reset high), the reset pulse spacing, the S3706's TCM handshake, and every register the chip is asked for. |
| `touch/touchpanel_common_driver.c`, `.h` | The shared power helpers: `tp_powercontrol_1v8()` enables the `vcc_1v8` regulator and drives `enable1v8_gpio` (active low in the tree) high logically, i.e. the pin low; `vdd_2v8` is enabled through the regulator framework. |
| `touch/kernelFwUpdate.c`, `tp_devices.h` | The firmware-update path and the device table. |

## soc, clk, pinctrl, spmi, i2c — the bus and clock hardware

| File | What it answers |
|---|---|
| `soc/cmd-db.c` | **The command database this phone's bootloader builds** — the table this port already parses by hand; the vendor's struct layout and lookup rules. |
| `soc/rpmh.c` | The RPMh client: how a vote becomes a TCS command. |
| `soc/smp2p.c` | The SMP2P driver, fetched 2026-11-02 (byte-verified): the entry and item layout, the subsystem-item lookup — what `drivers/wifi/hakios.wifi.c`'s item allocation must be checked against. |
| `soc/wcnss_wlan.c` | The older (pre-icnss) WLAN platform driver: PIL device name → SMP2P entry → rpmsg channel (`WCNSS_CTRL`) in one file. The pattern, not this phone's driver — this phone's WLAN is `wifi/icnss.c`. |
| `clk/gcc-sm8150.c` | Every QUPv3 branch and rcg on this SoC: the vote register 0x52014, the per-SE halt registers, the wrapper reset at 0x1e000. |
| `clk/clk-rcg2.c`, `clk-branch.c` | **Why the engine's clock root has to be enabled by hand**: the vendor's `clk_rcg2_ops` carries `.enable = clk_rcg2_enable`, which writes `CMD_ROOT_EN` (bit 1) and waits for `CMD_ROOT_OFF` (bit 31) — the write this port was missing. |
| `clk/clk-rpmh.c` | The RPMh-managed clocks (the `corex` class). |
| `pinctrl/pinctrl-sm8150.c` | The pin table: which TLMM tile holds which pin, and the functions each pin offers (qup17 on gpio55/56, qup15 on gpio27/28, qup1 on gpio114/115). |
| `pinctrl/pinctrl-msm.c` | **The TLMM register encoding**: pull 0 = none, 1 = down, 2 = keeper, 3 = up (`MSM_NO_PULL`, `MSM_PULL_DOWN`, `MSM_KEEPER`, `MSM_PULL_UP`). Value 2 is the keeper that held the touch bus low. |
| `pinctrl/pinctrl-spmi-gpio.c` | The PMIC GPIOs (the touch's 1.8 V enable on the PM8150L's GPIO5, the volume keys). |
| `spmi/spmi-pmic-arb.c` | The SPMI arbiter: channels, owners, the `chnls` write path this port uses. |
| `i2c/i2c-qcom-geni.c` | **Why the QUPv3 serial engines cannot do FIFO I2C on this phone**: the driver's GPI-only path, and how it uses the DMA channels the tree gives every i2c node. |
| `i2c/qcom-geni-se.c` | The wrapper: the SE protocol/clock setup, `geni_se_io_init()` and `geni_se_select_fifo_mode()`. |

## display — the backlight

| File | What it answers |
|---|---|
| `display/qcom-spmi-wled.c` | The PM8150L's WLED (`qcom,wled@d800`, label "backlight"): the module/brightness registers that make the screen actually dark when backboardd asks for blanking. |

## input — the keys

| File | What it answers |
|---|---|
| `input/qpnp-power-on.c` | The PON block: KPDPWR/RESIN status bits, debounce, pull configuration (the power key this port reads). |

## wifi — the WLAN subsystem

| File | What it answers |
|---|---|
| `wifi/icnss.c`, `wifi/icnss_private.h`, `wifi/icnss.txt` | **This phone's WLAN driver**: the DT node is `qcom,icnss@18800000`. The power sequence, the Q6/wcnproc calls, and the QMI channel names — the M3/M4 message order lives here. |
| `wifi/qcom,wcnss.txt` | The older wcnss binding, for reading `soc/wcnss_wlan.c` against. |

The fetch settled a question the notes left open: **there is no `ath/wcn3990` client in this
kernel generation** (checked on four branches of the OnePlus SM8150 msm-4.14 mirror; `ath/`
carries only `wcn36xx`). The wcn3990 in the DT is the Bluetooth side. The WLAN's `q6_ops`
provider is `techpack/wifi/wcnproc/` (`q6_ops.c`, `q6_mcc.c`, `q6_ol_fw.c`), outside the kernel
repo — still to fetch. See `notes/wifi.md` §8.

## dtb — this phone's own device tree

| File | What it answers |
|---|---|
| `dtb/boot.bin.01.dts` | The device tree the kernel is started with: QUP wrappers and SEs, SPMI slaves, the SMB5, the PON blocks, the TLMM window. |
| `dtb/dtbo.bin.01.dts` | The overlay the Android kernel merges: the touch node (`synaptics19081@20` with `reset-gpio`, `enable1v8_gpio`, `vdd_2v8`), the gauge (`bq27541-battery@55`), the charging parts, the panel and the WLED. Its `qupv3_se15_i2c` claim for the gauge is wrong — see the next row. |
| `dtb/android-merged.dts` | **The phone's merged Android device tree**, decompiled from the base DT appended to `prebuilt/Image-dtb` (the TWRP device-tree repository). This is the numbering the overlay's raw phandles refer to, and it is what names the gauge's real bus: **`i2c@a80000` (SE8), pins gpio88/gpio89 in the north tile** — not SE15. |

## What this settles, and what is still open

- The pack gauge's registers are known (`power/oplus_bq27541.h`) — the port reads 0x2C/0x08/0x14/0x06.
- The touch's power model is known: `pm8150_l17` (an RPMh VRM vote at 3.0 V) plus the PM8150L GPIO5
  load switch (active low), plus the reset line (active low). The port drives the switch and the
  reset; it does not yet make the RPMh vote for L17.
- The serial engine's FIFO is fused off on this SoC (`i2c/i2c-qcom-geni.c`), so I2C on this phone is
  bit-banged in the port's own drivers.
- The gauge's bus still shows no powered slave; the vendor's charging stack
  (`power/oplus_battery_msm8150.c`) is where to look next for what turns that bus's supply on.
