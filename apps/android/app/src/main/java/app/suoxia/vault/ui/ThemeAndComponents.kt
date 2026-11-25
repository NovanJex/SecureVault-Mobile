package app.suoxia.vault.ui

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import app.suoxia.vault.i18n.t
import app.suoxia.vault.model.ItemType
import app.suoxia.vault.model.VaultItem

val SvIndigo = Color(0xFF4F46E5)
val SvViolet = Color(0xFF7C3AED)
val SvRose = Color(0xFFE11D48)
val SvEmerald = Color(0xFF059669)
val SvAmber = Color(0xFFD97706)
val SvSky = Color(0xFF0284C7)

data class SvToastState(
    val message: String? = null,
    val isWarn: Boolean = false
)

val LocalSvToastState = compositionLocalOf { SvToastState() }

@Composable
fun BoxScope.SvToastOverlay(bottomPadding: Dp = 24.dp) {
    val toast = LocalSvToastState.current
    toast.message?.let { msg ->
        Surface(
            shape = RoundedCornerShape(24.dp),
            color = Color(0xF20F172A),
            shadowElevation = 8.dp,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .navigationBarsPadding()
                .imePadding()
                .padding(bottom = bottomPadding, start = 24.dp, end = 24.dp)
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = if (toast.isWarn) "!" else "✓",
                    color = if (toast.isWarn) Color(0xFFFBBF24) else Color(0xFF34D399),
                    fontWeight = FontWeight.Bold,
                    fontSize = 13.sp
                )
                Text(msg, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Medium)
            }
        }
    }
}

data class SvPalette(
    val isDark: Boolean,
    val bg: Color,
    val card: Color,
    val sub: Color,
    val fg: Color,
    val border: Color,
    val hairline: Color
)

fun svPalette(isDark: Boolean): SvPalette = if (isDark) {
    SvPalette(
        isDark = true,
        bg = Color(0xFF0B0F19),
        card = Color(0xFF111827),
        sub = Color(0xFF1E293B),
        fg = Color(0xFFF1F5F9),
        border = Color(0xFF1E293B),
        hairline = Color(0x12FFFFFF)
    )
} else {
    SvPalette(
        isDark = false,
        bg = Color(0xFFF2F2F7),
        card = Color.White,
        sub = Color(0xFFF1F5F9),
        fg = Color(0xFF0F172A),
        border = Color(0xB3E2E8F0),
        hairline = Color(0x0F0F172A)
    )
}

@Composable
fun SvHairlineDivider(p: SvPalette, inset: Dp = 16.dp) {
    HorizontalDivider(
        modifier = Modifier.padding(horizontal = inset),
        thickness = 1.dp,
        color = p.hairline
    )
}

@Composable
fun SvGroupedCard(
    p: SvPalette,
    modifier: Modifier = Modifier,
    radius: Dp = 16.dp,
    content: @Composable ColumnScope.() -> Unit
) {
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(radius),
        color = p.card,
        border = BorderStroke(1.dp, p.border)
    ) {
        Column(content = content)
    }
}

@Composable
fun SvSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier
) {
    val bgColor by animateColorAsState(
        targetValue = if (checked) SvIndigo else Color(0x5994A3B8),
        animationSpec = tween(200),
        label = "swBg"
    )
    val thumbOffset by animateDpAsState(
        targetValue = if (checked) 18.dp else 0.dp,
        animationSpec = tween(200),
        label = "swThumb"
    )
    Box(
        modifier = modifier
            .size(width = 44.dp, height = 26.dp)
            .clip(CircleShape)
            .background(bgColor)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { onCheckedChange(!checked) }
            .padding(3.dp)
    ) {
        Box(
            modifier = Modifier
                .offset(x = thumbOffset)
                .size(20.dp)
                .clip(CircleShape)
                .background(Color.White)
        )
    }
}

@Composable
fun SvInputField(
    p: SvPalette,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    label: String? = null,
    labelEnd: (@Composable () -> Unit)? = null,
    isPassword: Boolean = false,
    initiallyVisible: Boolean = false,
    monospace: Boolean = false,
    height: Dp = 40.dp,
    borderColorOverride: Color? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default
) {
    var visible by remember(initiallyVisible) { mutableStateOf(initiallyVisible) }
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (label != null || labelEnd != null) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (label != null) {
                    Text(
                        text = label,
                        fontSize = 11.sp,
                        color = p.fg.copy(alpha = 0.6f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                } else {
                    Spacer(Modifier.width(1.dp))
                }
                labelEnd?.invoke()
            }
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(height)
                .clip(RoundedCornerShape(12.dp))
                .background(p.card)
                .border(1.dp, borderColorOverride ?: p.border, RoundedCornerShape(12.dp))
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) {
                    Text(
                        text = placeholder,
                        fontSize = 12.sp,
                        color = p.fg.copy(alpha = 0.4f),
                        fontFamily = FontFamily.Default,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                BasicTextField(
                    value = value,
                    onValueChange = onValueChange,
                    singleLine = true,
                    textStyle = TextStyle(
                        fontSize = 12.sp,
                        color = p.fg,
                        fontFamily = if (monospace) FontFamily.Monospace else FontFamily.Default
                    ),
                    cursorBrush = SolidColor(SvIndigo),
                    visualTransformation = if (isPassword && !visible) PasswordVisualTransformation() else VisualTransformation.None,
                    keyboardOptions = keyboardOptions,
                    modifier = Modifier.fillMaxWidth()
                )
            }
            if (isPassword) {
                IconButton(
                    onClick = { visible = !visible },
                    modifier = Modifier.size(28.dp)
                ) {
                    Icon(
                        imageVector = if (visible) Icons.Outlined.VisibilityOff else Icons.Outlined.Visibility,
                        contentDescription = null,
                        tint = p.fg.copy(alpha = 0.5f),
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        }
    }
}

@Composable
fun SvTextAreaField(
    p: SvPalette,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    label: String? = null,
    minHeight: Dp = 64.dp,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (label != null) {
            Text(
                text = label,
                fontSize = 11.sp,
                color = p.fg.copy(alpha = 0.6f),
                modifier = Modifier.padding(horizontal = 4.dp)
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = minHeight)
                .clip(RoundedCornerShape(12.dp))
                .background(p.card)
                .border(1.dp, p.border, RoundedCornerShape(12.dp))
                .padding(horizontal = 14.dp, vertical = 10.dp)
        ) {
            if (value.isEmpty()) {
                Text(
                    text = placeholder,
                    fontSize = 12.sp,
                    color = p.fg.copy(alpha = 0.4f)
                )
            }
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                textStyle = TextStyle(fontSize = 12.sp, color = p.fg, lineHeight = 18.sp),
                cursorBrush = SolidColor(SvIndigo),
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
fun SvSearchBar(
    p: SvPalette,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(36.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(p.card)
            .border(1.dp, p.border, RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Icon(
            imageVector = Icons.Filled.Search,
            contentDescription = null,
            tint = p.fg.copy(alpha = 0.45f),
            modifier = Modifier.size(16.dp)
        )
        Box(modifier = Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (value.isEmpty()) {
                Text(
                    text = placeholder,
                    fontSize = 12.sp,
                    color = p.fg.copy(alpha = 0.45f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            BasicTextField(
                value = value,
                onValueChange = onValueChange,
                singleLine = true,
                textStyle = TextStyle(fontSize = 12.sp, color = p.fg),
                cursorBrush = SolidColor(SvIndigo),
                modifier = Modifier.fillMaxWidth()
            )
        }
        if (value.isNotEmpty()) {
            Icon(
                imageVector = Icons.Filled.Close,
                contentDescription = null,
                tint = p.fg.copy(alpha = 0.45f),
                modifier = Modifier
                    .size(16.dp)
                    .clickable { onValueChange("") }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SvPageSheet(
    p: SvPalette,
    title: String,
    onDismiss: () -> Unit,
    leftLabel: String = t("取消"),
    onLeftClick: () -> Unit = onDismiss,
    rightAction: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val maxHeight = (LocalConfiguration.current.screenHeightDp * 0.89f).dp

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = p.bg,
        contentColor = p.fg,
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(top = 10.dp, bottom = 4.dp)
                    .width(40.dp)
                    .height(4.dp)
                    .clip(CircleShape)
                    .background(Color(0x4D64748B))
            )
        }
    ) {
        Box(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = maxHeight)
                    .navigationBarsPadding()
                    .imePadding()
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(44.dp)
                        .padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (leftLabel.startsWith("‹ ")) {
                        Box(
                            modifier = Modifier
                                .size(32.dp)
                                .clip(CircleShape)
                                .background(p.sub)
                                .border(0.8.dp, p.border, CircleShape)
                                .clickable { onLeftClick() },
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(
                                Icons.Filled.ChevronLeft,
                                contentDescription = leftLabel.removePrefix("‹ "),
                                tint = p.fg.copy(alpha = 0.8f),
                                modifier = Modifier.size(18.dp)
                            )
                        }
                    } else {
                        Text(
                            text = leftLabel,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Medium,
                            color = p.fg.copy(alpha = 0.6f),
                            modifier = Modifier.clickable { onLeftClick() }.padding(vertical = 6.dp)
                        )
                    }
                    Text(
                        text = title,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold,
                        color = p.fg,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                    Box(modifier = Modifier.defaultMinSize(minWidth = 40.dp), contentAlignment = Alignment.CenterEnd) {
                        rightAction?.invoke()
                    }
                }
                HorizontalDivider(thickness = 1.dp, color = p.hairline)
                content()
            }
            SvToastOverlay(bottomPadding = 16.dp)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SvActionSheet(
    p: SvPalette,
    onDismiss: () -> Unit,
    content: @Composable ColumnScope.() -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        containerColor = p.card,
        contentColor = p.fg,
        dragHandle = {
            Box(
                modifier = Modifier
                    .padding(top = 10.dp, bottom = 4.dp)
                    .width(40.dp)
                    .height(4.dp)
                    .clip(CircleShape)
                    .background(Color(0x4D64748B))
            )
        }
    ) {
        Box(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .padding(top = 4.dp, bottom = 24.dp)
                    .navigationBarsPadding()
                    .imePadding(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                content = content
            )
            SvToastOverlay(bottomPadding = 16.dp)
        }
    }
}

@Composable
fun SvConfirmDialog(
    p: SvPalette,
    title: String,
    message: String,
    confirmText: String,
    isDestructive: Boolean = true,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier.widthIn(max = 310.dp).fillMaxWidth(0.84f),
            shape = RoundedCornerShape(24.dp),
            color = p.card,
            border = BorderStroke(1.dp, p.border),
            shadowElevation = 16.dp
        ) {
            Column(
                modifier = Modifier.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = p.fg,
                    textAlign = TextAlign.Center
                )
                Text(
                    text = message,
                    fontSize = 12.sp,
                    color = p.fg.copy(alpha = 0.65f),
                    textAlign = TextAlign.Center,
                    lineHeight = 18.sp
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = p.sub,
                        border = BorderStroke(1.dp, p.border),
                        modifier = Modifier
                            .weight(1f)
                            .height(40.dp)
                            .clickable { onDismiss() }
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(t("取消"), fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = p.fg)
                        }
                    }
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = if (isDestructive) SvRose else SvIndigo,
                        modifier = Modifier
                            .weight(1f)
                            .height(40.dp)
                            .clickable { onConfirm() }
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Text(confirmText, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                        }
                    }
                }
            }
        }
    }
}

fun colorizePasswordAnnotated(pwd: String): AnnotatedString = buildAnnotatedString {
    pwd.forEach { ch ->
        when {
            ch.isDigit() -> withStyle(SpanStyle(color = Color(0xFF38BDF8))) { append(ch) }
            !ch.isLetterOrDigit() -> withStyle(SpanStyle(color = Color(0xFFFBBF24))) { append(ch) }
            else -> withStyle(SpanStyle(color = Color.White)) { append(ch) }
        }
    }
}

@Composable
fun ItemAvatar(item: VaultItem, modifier: Modifier = Modifier) {
    if (item.type == ItemType.LOGIN) {
        val letter = item.title.trim().firstOrNull()?.uppercaseChar()?.toString() ?: "S"
        val palette = listOf(Color(0xFF1E293B), SvIndigo, SvSky, SvEmerald)
        val bgColor = palette[letter[0].code % palette.size]
        Box(
            modifier = modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(bgColor),
            contentAlignment = Alignment.Center
        ) {
            Text(letter, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
    } else {
        val (bgColor, tint, icon) = when (item.type) {
            ItemType.CARD -> Triple(SvEmerald.copy(alpha = 0.12f), SvEmerald, Icons.Outlined.CreditCard)
            ItemType.NOTE -> Triple(SvSky.copy(alpha = 0.12f), SvSky, Icons.Outlined.Description)
            ItemType.IDENTITY -> Triple(SvAmber.copy(alpha = 0.12f), SvAmber, Icons.Outlined.Badge)
            else -> Triple(SvIndigo.copy(alpha = 0.12f), SvIndigo, Icons.Outlined.Lock)
        }
        Box(
            modifier = modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(bgColor),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
fun SvGradientButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    radius: Dp = 999.dp
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(radius))
            .background(Brush.horizontalGradient(listOf(SvIndigo, SvViolet)))
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        Text(text, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
    }
}
