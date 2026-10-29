#!/bin/sh
# The MT8163 thermal controller on mainline's auxadc_thermal.c, set up as Amazon's
# drivers/misc/mediatek/thermal/mt8163/mtk_ts_cpu.c (android_kernel_amazon_mt8163) does: the bank
# reads TS3 (that file's TS_MCU1, the CPU's) and not TS2 (its TS_ABB); the AUXADC channel is taken
# from the AUXADC (AUXADC_CON1_CLR, then _SET) around the controller's setup; TS_CON1[5:4] is
# cleared, the sensor buffer on towards the AUXADC; and TEMPMSRCTL1's 0x10e bits are cleared.
# Idempotent.
set -eu
python3 - <<'PY'
import os
from pathlib import Path
p = Path(os.environ.get('KDIR', '/src/linux-7.2.13')) / 'drivers/thermal/mediatek/auxadc_thermal.c'
s = p.read_text()
if '/* MT8163 AUXADC channel ownership */' in s:
    raise SystemExit(0)
start = s.index('static const int mt8163_bank_data')
end = s.index('};', start)
bank = s[start:end].replace('{ MT8163_TS2 },', '{ MT8163_TS3 },')
s = s[:start] + bank + s[end:]
start = s.index('static const struct mtk_thermal_data mt8163_thermal_data')
end = s.index('\n};', start)
s = s[:end] + '''
	.apmixed_buffer_ctl_reg = APMIXED_SYS_TS_CON1,
	.apmixed_buffer_ctl_mask = (u32)~GENMASK(5, 4),
	.apmixed_buffer_ctl_set = 0,''' + s[end:]
anchor = '\tfor (ctrl_id = 0; ctrl_id < mt->conf->num_controller ; ctrl_id++)'
assert s.count(anchor) == 1
s = s.replace(anchor, '''	/* MT8163 AUXADC channel ownership */
	if (mt->conf == &mt8163_thermal_data) {
		u32 value = readl(auxadc_base);

		writel(value & ~BIT(mt->conf->auxadc_channel), auxadc_base);
		writel(BIT(mt->conf->auxadc_channel), auxadc_base + AUXADC_CON1_CLR_V);
	}

''' + anchor)
anchor = '\tfor (i = 0; i < mt->conf->num_banks; i++) {\n\t\tstruct mtk_thermal_bank *bank'
assert s.count(anchor) == 1
s = s.replace(anchor, '''	if (mt->conf == &mt8163_thermal_data) {
		writel(BIT(mt->conf->auxadc_channel), auxadc_base + AUXADC_CON1_SET_V);
		for (i = 0; i < mt->conf->num_banks; i++) {
			u32 value;

			mtk_thermal_get_bank(&mt->banks[i]);
			value = readl(mt->thermal_base + TEMP_MSRCTL1);
			writel(value & ~0x10e, mt->thermal_base + TEMP_MSRCTL1);
			mtk_thermal_put_bank(&mt->banks[i]);
		}
	}

''' + anchor)
p.write_text(s)
PY
