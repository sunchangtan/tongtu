package mihomocore
import ("os";"testing")
func TestStressFixtureParses(t *testing.T) {
    b, err := os.ReadFile("../testdata/stress-config.yaml")
    if err != nil { t.Fatal(err) }
    if _, err := buildRawConfig(string(b), coreOverrides{}); err != nil {
        t.Fatalf("压测 fixture 解析失败: %v", err)
    }
}
