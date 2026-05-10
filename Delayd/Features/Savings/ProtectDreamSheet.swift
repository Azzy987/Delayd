import SwiftUI
import SwiftData

struct ProtectDreamSheet: View {
    @State private var viewModel: ProtectDreamViewModel
    @State private var isDatePickerPresented = false
    @State private var isKeypadVisible = true

    let onClose: () -> Void
    let onProtected: (DreamBoostImpact) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    private let hapticService = HapticService()

    @MainActor
    init(
        viewModel: ProtectDreamViewModel? = nil,
        onClose: @escaping () -> Void = {},
        onProtected: @escaping (DreamBoostImpact) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel ?? ProtectDreamViewModel())
        self.onClose = onClose
        self.onProtected = onProtected
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.sm) {
                    linkedGoalCard
                    amountCard
                    locationCard
                    sourceCard
                    dateCard
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)
            }

            VStack(spacing: 0) {
                keypadHeader

                if isKeypadVisible {
                    NumericKeypad(
                        text: $viewModel.amountText,
                        keyHeight: 42,
                        keySpacing: 8,
                        horizontalPadding: AppSpacing.lg,
                        verticalPadding: AppSpacing.sm,
                        digitFontSize: 22,
                        showsBackground: false,
                        onKeyTap: { hapticService.playLightImpact() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                PrimaryButton("Protect Dream", isLoading: viewModel.isSaving) {
                    submit()
                }
                .disabled(!viewModel.canSave)
                .opacity(viewModel.canSave ? 1 : 0.48)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.md)
            }
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 24
                )
                .fill(AppColors.card(for: colorScheme))
                .ignoresSafeArea(edges: .bottom)
            )
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 24, bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0, topTrailingRadius: 24
                )
            )
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
        .interactiveDismissDisabled(viewModel.isSaving)
        .task {
            hapticService.playLightImpact()
            await viewModel.load(modelContainer: modelContext.container)
        }
        .sheet(isPresented: $isDatePickerPresented) {
            datePickerSheet
                .delaydPageSheet(detents: [.medium])
        }
    }

    private var topBar: some View {
        ZStack {
            Text("Protect Dream")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                        .frame(width: 36, height: 36)
                        .background(AppColors.surface(for: colorScheme), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppColors.border(for: colorScheme), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)

                Spacer()
            }
        }
    }

    private var linkedGoalCard: some View {
        HStack(spacing: AppSpacing.md) {
            GoalCategoryIcon(category: viewModel.selectedGoal.category)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Protecting")
                    .font(AppTypography.captionMedium)
                    .foregroundStyle(AppColors.textSecondary(for: colorScheme))

                Text(viewModel.selectedGoal.name.delaydGoalTitleCased)
                    .font(AppTypography.bodyMedium)
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: AppSpacing.sm)

            Menu {
                ForEach(viewModel.goals) { goal in
                    Button {
                        viewModel.selectGoal(goal)
                        hapticService.playLightImpact()
                    } label: {
                        if goal == viewModel.selectedGoal {
                            Label(goal.name.delaydGoalTitleCased, systemImage: "checkmark")
                        } else {
                            Text("\(goal.emoji)  \(goal.name.delaydGoalTitleCased)")
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Change")
                        .font(AppTypography.callout)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(AppColors.purplePrimary)
            }
            .disabled(viewModel.isSaving || viewModel.goals.count <= 1)
            .opacity(viewModel.goals.count <= 1 ? 0.45 : 1)
        }
        .protectCard(colorScheme: colorScheme)
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Amount protected")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(CurrencyFormatter.symbol(for: viewModel.currencyCode))
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .foregroundStyle(AppColors.textPrimary(for: colorScheme))

                Text(viewModel.amountText.isEmpty ? "0" : viewModel.amountText)
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .foregroundStyle(
                        viewModel.amountText.isEmpty
                            ? AppColors.textTertiary(for: colorScheme)
                            : AppColors.textPrimary(for: colorScheme)
                    )
                    .minimumScaleFactor(0.48)
                    .lineLimit(1)

                BlinkingCaret()
                    .frame(width: 2, height: 30)
                    .foregroundStyle(AppColors.positive)
            }

            Text(viewModel.encouragementLine)
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.positive)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .protectCard(colorScheme: colorScheme)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AppMotion.sheetPresentation) {
                isKeypadVisible = true
            }
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Where is it kept?")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(DreamSavingsLocation.allCases) { location in
                        let isSelected = location == viewModel.selectedLocation
                        Button {
                            viewModel.selectedLocation = location
                            hapticService.playLightImpact()
                        } label: {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: location.symbolName)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(location.title)
                                    .font(AppTypography.captionMedium)
                            }
                            .foregroundStyle(isSelected ? .white : AppColors.textPrimary(for: colorScheme))
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                isSelected
                                    ? AnyShapeStyle(AppGradients.heroGradient)
                                    : AnyShapeStyle(AppColors.softSurface(for: colorScheme)),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .protectCard(colorScheme: colorScheme)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Source (optional)")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(ProtectDreamViewModel.ProtectSource.allCases) { source in
                        let isSelected = viewModel.selectedSource == source
                        Button {
                            viewModel.selectedSource = isSelected ? nil : source
                            hapticService.playLightImpact()
                        } label: {
                            Text(source.rawValue)
                                .font(AppTypography.captionMedium)
                                .foregroundStyle(isSelected ? .white : AppColors.textPrimary(for: colorScheme))
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(
                                    isSelected
                                        ? AnyShapeStyle(AppGradients.heroGradient)
                                        : AnyShapeStyle(AppColors.softSurface(for: colorScheme)),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .protectCard(colorScheme: colorScheme)
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Date")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            Button {
                isDatePickerPresented = true
            } label: {
                HStack {
                    Text(formattedDate(viewModel.protectedDate))
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                    Spacer()
                    PhosphorIcon(.calendarBlank, size: 20)
                        .foregroundStyle(AppColors.textSecondary(for: colorScheme))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .protectCard(colorScheme: colorScheme)
    }

    private var keypadHeader: some View {
        HStack {
            Text("Keypad")
                .font(AppTypography.captionMedium)
                .foregroundStyle(AppColors.textSecondary(for: colorScheme))

            Spacer()

            Button {
                withAnimation(AppMotion.sheetPresentation) {
                    isKeypadVisible.toggle()
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(isKeypadVisible ? "Hide" : "Show")
                    Image(systemName: isKeypadVisible ? "keyboard.chevron.compact.down" : "keyboard")
                }
                .font(AppTypography.captionMedium)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.88) : AppColors.purplePrimary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(AppColors.purplePrimary.opacity(colorScheme == .dark ? 0.28 : 0.10), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }

    private var datePickerSheet: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("Pick a date")
                .font(AppTypography.bodyMedium)
                .foregroundStyle(AppColors.textPrimary(for: colorScheme))
                .padding(.top, AppSpacing.md)

            DatePicker(
                "Date",
                selection: $viewModel.protectedDate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.graphical)
            .tint(AppColors.purplePrimary)
            .padding(.horizontal, AppSpacing.md)

            Button("Done") {
                isDatePickerPresented = false
            }
            .font(AppTypography.bodyMedium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.purplePrimary, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
        .background(AppColors.background(for: colorScheme).ignoresSafeArea())
    }

    private func submit() {
        Task {
            guard let impact = await viewModel.protectDream() else { return }
            onProtected(impact)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}

private extension View {
    func protectCard(colorScheme: ColorScheme) -> some View {
        self
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 12)
            .background(AppColors.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(AppColors.border(for: colorScheme).opacity(colorScheme == .dark ? 0.7 : 0.85), lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.16 : 0.045),
                radius: 10,
                x: 0,
                y: 4
            )
    }
}

private struct ProtectDreamSheetPreviewHost: View {
    @State private var isPresented = true

    var body: some View {
        ZStack {
            AppColors.backgroundLight
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isPresented) {
            ProtectDreamSheet(viewModel: .mock(amount: "5000"))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview("Sheet") {
    ProtectDreamSheetPreviewHost()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.light)
}

#Preview("Content Dark") {
    ProtectDreamSheet(viewModel: .mock(amount: "3000"))
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
