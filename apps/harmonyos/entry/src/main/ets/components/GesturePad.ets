@ComponentV2
export struct GesturePad {
  @Param onPatternComplete: (pattern: string) => void = () => {};
  @Local selected: number[] = [];
  private readonly padSize: number = 216;
  private readonly centers: Array<[number, number]> = [
    [36, 36], [108, 36], [180, 36],
    [36, 108], [108, 108], [180, 108],
    [36, 180], [108, 180], [180, 180]
  ];
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  private redrawLine(): void {
    this.ctx.clearRect(0, 0, this.padSize, this.padSize);
    if (this.selected.length < 2) return;
    this.ctx.strokeStyle = '#4F46E5';
    this.ctx.lineWidth = 3;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.beginPath();
    this.selected.forEach((idx, i) => {
      const pt = this.centers[idx];
      if (i === 0) this.ctx.moveTo(pt[0], pt[1]);
      else this.ctx.lineTo(pt[0], pt[1]);
    });
    this.ctx.stroke();
  }

  private hitTest(x: number, y: number): void {
    for (let i = 0; i < this.centers.length; i++) {
      if (this.selected.includes(i)) continue;
      const dx = x - this.centers[i][0];
      const dy = y - this.centers[i][1];
      if (Math.hypot(dx, dy) <= 26) {
        this.selected = [...this.selected, i];
        this.redrawLine();
      }
    }
  }

  build() {
    Stack() {
      Canvas(this.ctx)
        .width(this.padSize)
        .height(this.padSize)

      ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8], (idx: number) => {
        Stack() {
          Circle({ width: 44, height: 44 })
            .fill(this.selected.includes(idx) ? '#1A4F46E5' : Color.Transparent)
            .stroke(this.selected.includes(idx) ? '#804F46E5' : Color.Transparent)
            .strokeWidth(2)
          Circle({ width: 14, height: 14 })
            .fill(this.selected.includes(idx) ? '#4F46E5' : '#6694A3B8')
        }
        .position({ x: this.centers[idx][0] - 22, y: this.centers[idx][1] - 22 })
      })
    }
    .width(this.padSize)
    .height(this.padSize)
    .onTouch((event: TouchEvent) => {
      const touch = event.touches[0];
      if (!touch) return;
      if (event.type === TouchType.Down) {
        this.selected = [];
        this.hitTest(touch.x, touch.y);
      } else if (event.type === TouchType.Move) {
        this.hitTest(touch.x, touch.y);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        const pattern = this.selected.join('');
        setTimeout(() => {
          this.selected = [];
          this.redrawLine();
        }, 160);
        if (pattern.length > 0) {
          this.onPatternComplete(pattern);
        }
      }
    })
  }
}
