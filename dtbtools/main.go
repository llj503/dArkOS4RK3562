// dtbTools-dArkOS — 机型切换工具 (精简版 dtbTools)
//
// 与 arkos4clone 的 dtbTools 不同: 所有 dtb 常驻 boot 分区根目录,
// 切换机型只需把 extlinux/conf.d/<dev>.conf 复制为 extlinux/extlinux.conf
// 并写入 /boot/.console 供开机 clone.sh 使用 — 不移动任何 dtb。
//
// 可执行文件放在 boot 分区根目录, PC (Windows/macOS/Linux) 上插卡直接运行,
// 也可在设备上运行 (重启生效)。
package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
)

var Version = "dev"

// ---------- 机型条目 ----------
type entry struct {
	dev  string // conf.d 文件名 (设备名)
	dtb  string // conf 里的 FDT 值, 用于校验 dtb 存在
}

type lang struct {
	title     string
	warn      string
	pick      string
	invalid   string
	missing   string
	current   string
	written   string
	noDtb     string
	bye       string
}

var L = lang{
	title:   "dArkOS dtb 选择器 v" + Version + "  (dtb 常驻根目录, 仅切换 extlinux.conf)",
	warn:    "请确认已在 boot 分区根目录运行本工具, 修改后安全弹出 SD 卡",
	pick:    "输入编号选择机型 (q 退出): ",
	invalid: "无效选择",
	missing: "未找到任何机型配置 (extlinux/conf.d/*.conf)",
	current: "当前机型",
	written: "已切换并写入 .console",
	noDtb:   "警告: 对应 dtb 不在根目录",
	bye:     "已取消, 未做任何修改",
}

func main() {
	baseDir, err := os.Getwd()
	if err != nil {
		fatal("无法确定当前目录: %v", err)
	}
	// exe 同目录优先 (双击运行时 cwd 可能不同)
	if exe, err := os.Executable(); err == nil {
		d := filepath.Dir(exe)
		if _, err := os.Stat(filepath.Join(d, "extlinux")); err == nil {
			baseDir = d
		}
	}

	fmt.Println(L.title)
	fmt.Println(L.warn)
	fmt.Println(strings.Repeat("-", 56))

	entries := scan(filepath.Join(baseDir, "extlinux", "conf.d"))
	if len(entries) == 0 {
		fatal(L.missing)
	}

	// 当前生效机型
	cur := "(未知)"
	if b, err := os.ReadFile(filepath.Join(baseDir, ".console")); err == nil {
		cur = strings.TrimSpace(string(b))
	}

	for i, e := range entries {
		mark := " "
		if e.dev == cur {
			mark = "*"
		}
		fmt.Printf("  %s %d) %-12s %s\n", mark, i+1, e.dev, e.dtb)
	}
	fmt.Printf("\n  %s: %s\n", L.current, cur)
	fmt.Print("\n" + L.pick)

	in := bufio.NewReader(os.Stdin)
	line, _ := in.ReadString('\n')
	line = strings.TrimSpace(line)
	if line == "" || line == "q" || line == "Q" {
		fmt.Println(L.bye)
		return
	}

	var n int
	if _, err := fmt.Sscanf(line, "%d", &n); err != nil || n < 1 || n > len(entries) {
		fatal(L.invalid)
	}
	e := entries[n-1]

	dtbPath := filepath.Join(baseDir, e.dtb)
	if _, err := os.Stat(dtbPath); err != nil {
		fmt.Println(L.noDtb + ": " + e.dtb)
	}

	// 唯一的写操作: conf.d/<dev>.conf -> extlinux/extlinux.conf
	src := filepath.Join(baseDir, "extlinux", "conf.d", e.dev+".conf")
	dst := filepath.Join(baseDir, "extlinux", "extlinux.conf")
	if err := copyFile(src, dst); err != nil {
		fatal("写入 extlinux.conf 失败: %v", err)
	}
	// .console 供开机 clone.sh 使用 (设备上 model 检测优先, 此文件为 PC 侧记录)
	if err := os.WriteFile(filepath.Join(baseDir, ".console"), []byte(e.dev+"\n"), 0644); err != nil {
		fatal("写入 .console 失败: %v", err)
	}

	fmt.Printf("\n✔ %s: %s\n", L.written, e.dev)
	fmt.Printf("  extlinux/extlinux.conf  <-  conf.d/%s.conf\n", e.dev)
	fmt.Printf("  FDT %s\n", e.dtb)
	if runtime.GOOS == "windows" {
		fmt.Println("\n请安全弹出 SD 卡后上机")
	} else {
		fmt.Println("\n请 sync/安全弹出后上机")
	}
}

// scan 读取 conf.d/*.conf, 解析 FDT 行; 返回按名称排序的条目
func scan(dir string) []entry {
	matches, err := filepath.Glob(filepath.Join(dir, "*.conf"))
	if err != nil {
		return nil
	}
	var out []entry
	for _, m := range matches {
		b, err := os.ReadFile(m)
		if err != nil {
			continue
		}
		e := entry{dev: strings.TrimSuffix(filepath.Base(m), ".conf")}
		for _, ln := range strings.Split(string(b), "\n") {
			ln = strings.TrimSpace(ln)
			if strings.HasPrefix(ln, "FDT") {
				f := strings.Fields(ln)
				if len(f) >= 2 {
					e.dtb = strings.TrimPrefix(f[1], "/")
				}
			}
		}
		if e.dtb != "" {
			out = append(out, e)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].dev < out[j].dev })
	return out
}

func copyFile(src, dst string) error {
	b, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	f, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = f.Write(b)
	return err
}

func fatal(format string, a ...any) {
	fmt.Printf("✘ "+format+"\n", a...)
	os.Exit(1)
}
