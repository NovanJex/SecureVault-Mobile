package app.suoxia.vault.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import kotlin.math.hypot

@Composable
fun GesturePad(
    onPatternComplete: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var selected by remember { mutableStateOf<List<Int>>(emptyList()) }
    var dragPos by remember { mutableStateOf<Offset?>(null) }

    Canvas(
        modifier = modifier
            .size(220.dp)
            .pointerInput(Unit) {
                val step = size.width / 3f
                val centers = (0 until 9).map { idx ->
                    val r = idx / 3
                    val c = idx % 3
                    Offset(c * step + step / 2f, r * step + step / 2f)
                }
                detectDragGestures(
                    onDragStart = { pos ->
                        selected = emptyList()
                        dragPos = pos
                        centers.forEachIndexed { idx, pt ->
                            if (hypot(pos.x - pt.x, pos.y - pt.y) <= step * 0.34f) {
                                selected = listOf(idx)
                            }
                        }
                    },
                    onDrag = { change, _ ->
                        change.consume()
                        val pos = change.position
                        dragPos = pos
                        centers.forEachIndexed { idx, pt ->
                            if (idx !in selected && hypot(pos.x - pt.x, pos.y - pt.y) <= step * 0.34f) {
                                selected = selected + idx
                            }
                        }
                    },
                    onDragEnd = {
                        val pat = selected.joinToString("")
                        selected = emptyList()
                        dragPos = null
                        if (pat.isNotEmpty()) onPatternComplete(pat)
                    },
                    onDragCancel = {
                        selected = emptyList()
                        dragPos = null
                    }
                )
            }
    ) {
        val step = size.width / 3f
        val centers = (0 until 9).map { idx ->
            val r = idx / 3
            val c = idx % 3
            Offset(c * step + step / 2f, r * step + step / 2f)
        }

        if (selected.isNotEmpty()) {
            val path = Path().apply {
                selected.forEachIndexed { i, idx ->
                    val pt = centers[idx]
                    if (i == 0) moveTo(pt.x, pt.y) else lineTo(pt.x, pt.y)
                }
                dragPos?.let { lineTo(it.x, it.y) }
            }
            drawPath(
                path = path,
                color = Color(0xFF4F46E5),
                style = Stroke(width = 8f, cap = StrokeCap.Round, join = StrokeJoin.Round)
            )
        }

        centers.forEachIndexed { idx, pt ->
            val active = idx in selected
            if (active) {
                drawCircle(color = Color(0x264F46E5), radius = 44f, center = pt)
                drawCircle(color = Color(0x804F46E5), radius = 44f, center = pt, style = Stroke(width = 4f))
            }
            drawCircle(
                color = if (active) Color(0xFF4F46E5) else Color(0x6694A3B8),
                radius = if (active) 16f else 12f,
                center = pt
            )
        }
    }
}
