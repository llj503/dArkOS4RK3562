p = r'F:/pocketAis/darkos/dtb/tf_patch/ro520c_aic.dts'
s = open(p, encoding='utf-8', errors='ignore').read()
old = '\\0a-key\\0x-key'
new = '\\0b-key\\0x-key'
print('matches:', s.count(old))
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
