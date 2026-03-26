import ComposableArchitecture
import SwiftUI

struct AmbientSoundMixerView: View {
    @Bindable var store: StoreOf<WorkSuiteReducer>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Active sounds indicator
                    if !store.ambientSounds.isEmpty {
                        GlassCard {
                            HStack {
                                Image(systemName: "speaker.wave.3.fill")
                                    .foregroundStyle(Color.axisGold)
                                Text("\(store.ambientSounds.count) sound\(store.ambientSounds.count == 1 ? "" : "s") playing")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("Stop All") {
                                    store.send(.stopAllSounds)
                                }
                                .font(.caption)
                                .foregroundStyle(.red)
                            }
                        }
                    }

                    // Sound sliders
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ambient Sounds")
                                .font(.headline)

                            ForEach(AudioService.availableSounds, id: \.self) { sound in
                                soundSlider(sound)
                            }
                        }
                    }

                    // Focus Profiles
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Focus Profiles")
                                    .font(.headline)
                                Spacer()
                                Button {
                                    store.send(.toggleSaveProfile)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.axisGold)
                                }
                            }

                            if store.focusProfiles.isEmpty {
                                Text("Save your current sound mix as a profile")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(store.focusProfiles) { profile in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(profile.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("\(profile.durationMinutes)min \u{2022} \(profile.soundVolumes.count) sounds")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Load") {
                                        store.send(.loadFocusProfile(profile.id))
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.axisGold.opacity(0.15))
                                    .foregroundStyle(Color.axisGold)
                                    .clipShape(Capsule())

                                    Button {
                                        store.send(.deleteFocusProfile(profile.id))
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sound Mixer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.send(.dismissAmbientMixer)
                    }
                }
            }
            .alert("Save Profile", isPresented: Binding(
                get: { store.showSaveProfile },
                set: { newValue in
                    if !newValue { store.send(.dismissSaveProfile) }
                }
            )) {
                TextField("Profile name", text: $store.newProfileName.sending(\.newProfileNameChanged))
                Button("Save") { store.send(.saveFocusProfile) }
                Button("Cancel", role: .cancel) { store.send(.dismissSaveProfile) }
            } message: {
                Text("Save current \(store.focusSessionMinutes)min timer with \(store.ambientSounds.count) sound(s)")
            }
        }
    }

    private func soundSlider(_ sound: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: AudioService.iconFor(sound))
                .font(.title3)
                .foregroundStyle(store.ambientSounds[sound] != nil ? Color.axisGold : .secondary)
                .frame(width: 28)

            Text(AudioService.labelFor(sound))
                .font(.subheadline)
                .frame(width: 90, alignment: .leading)

            Slider(
                value: Binding(
                    get: { Double(store.ambientSounds[sound] ?? 0) },
                    set: { store.send(.setAmbientVolume(sound, Float($0))) }
                ),
                in: 0...1
            )
            .tint(Color.axisGold)
        }
    }
}
