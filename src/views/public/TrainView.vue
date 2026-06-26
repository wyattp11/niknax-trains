<template>
  <div class="min-h-screen bg-base flex flex-col">

    <!-- ── Top accent stripe + back nav ── -->
    <div class="h-3 bg-niknax-600 shrink-0"></div>
    <div class="px-4 sm:px-6 py-3 border-b border-bd flex items-center justify-between max-w-4xl mx-auto w-full">
      <RouterLink to="/" class="font-display text-niknax-600 dark:text-niknax-400 hover:text-niknax-500 text-sm tracking-wide transition-colors">
        ← Niknax Train Station
      </RouterLink>
      <div class="flex items-center gap-3">
        <button
          @click="theme.toggle()"
          class="text-tx3 hover:text-tx1 transition-colors text-base"
          :title="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
          :aria-label="theme.isDark ? 'Switch to light mode' : 'Switch to dark mode'"
        ><ion-icon :name="theme.isDark ? 'sunny-outline' : 'moon-outline'" aria-hidden="true"></ion-icon></button>
        <button
          @click="theme.toggleSound()"
          class="text-base text-tx3 hover:text-tx1 transition-colors"
          :title="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
          :aria-label="theme.isSoundMuted ? 'Turn on sounds' : 'Mute sounds'"
          :aria-pressed="theme.isSoundMuted"
        ><ion-icon :name="theme.isSoundMuted ? 'volume-mute-outline' : 'volume-high-outline'" aria-hidden="true"></ion-icon></button>
        <button
          @click="theme.togglePalm()"
          class="text-base transition-colors"
          :class="theme.isPalm ? 'text-niknax-600 dark:text-niknax-400' : 'text-tx3 hover:text-tx1'"
          :title="theme.isPalm ? 'Turn off Palm Springs theme' : 'Turn on Palm Springs theme'"
          :aria-label="theme.isPalm ? 'Turn off Palm Springs theme' : 'Turn on Palm Springs theme'"
          :aria-pressed="theme.isPalm"
        ><ion-icon name="leaf-outline" aria-hidden="true"></ion-icon></button>
        <button
          @click="startSignupTour"
          class="text-tx3 hover:text-tx1 transition-colors text-base"
          title="How do I sign up?"
          aria-label="How do I sign up?"
        ><ion-icon name="help-circle-outline" aria-hidden="true"></ion-icon></button>
      </div>
    </div>

    <div v-if="loading" class="text-center py-32 text-tx3">Loading…</div>

    <template v-else-if="train">
      <!-- Hero — 60s style: strong typography, optional photo strip -->
      <div
        class="relative border-b border-bd"
        :class="train.cover_url ? '' : 'bg-base'"
        :style="train.cover_url ? `background-image: url(${train.cover_url}); background-size: cover; background-position: center;` : ''"
      >
        <div
          class="px-6 py-10 max-w-4xl mx-auto"
          :class="train.cover_url ? 'bg-black/70 backdrop-blur-sm' : ''"
        >
          <!-- Eyebrow -->
          <p class="text-[0.6rem] font-mono tracking-[0.5em] uppercase mb-3"
             :class="train.cover_url ? 'text-white/60' : 'text-tx3'">
            Niknax Train Station · Raid Train
          </p>
          <span :class="`badge-${STATUS_BADGE_CLASS[status.key]}`" class="inline-block mb-3">
            {{ status.label }}
          </span>
          <h1 class="font-display leading-tight mb-2"
              :class="['text-3xl sm:text-5xl', train.cover_url ? 'text-white' : 'text-tx1']">
            {{ train.name }}
          </h1>
          <p v-if="train.tagline"
             class="text-lg mb-3"
             :class="train.cover_url ? 'text-white/80' : 'text-tx2'">
            {{ train.tagline }}
          </p>
          <p v-if="train.description"
             class="mb-5 max-w-2xl text-sm"
             :class="train.cover_url ? 'text-white/70' : 'text-tx3'">
            {{ train.description }}
          </p>

          <div class="flex flex-col sm:flex-row sm:flex-wrap gap-3">
            <a
              v-if="effectiveDistrictLink"
              :href="effectiveDistrictLink"
              target="_blank"
              rel="noopener"
              class="btn-primary text-sm text-center"
            >
              Watch on District ↗
            </a>
            <button @click="copyPageLink" data-tour="share-button" class="btn-secondary text-sm flex items-center justify-center gap-1.5" aria-live="polite">
              <ion-icon :name="pageLinkCopied ? 'checkmark-circle-outline' : 'share-social-outline'" aria-hidden="true"></ion-icon>
              {{ pageLinkCopied ? 'Copied!' : 'Share Event' }}
            </button>
            <details v-if="trainCalendarRange" class="calendar-menu relative">
              <summary class="list-none cursor-pointer text-center whitespace-nowrap bg-[#FEA0CE] hover:bg-[#F9927C] text-[#2A2118] text-sm font-semibold px-4 py-2 rounded-lg transition-colors">
                Remind Me
              </summary>
              <div class="mt-1 sm:absolute sm:left-0 sm:z-20 sm:w-44 bg-surface border-2 border-[#FEA0CE] rounded-lg p-1 shadow-lg shadow-[#FEA0CE]/20">
                <a
                  :href="googleTrainCalendarUrl"
                  target="_blank"
                  rel="noopener"
                  class="block rounded-md px-3 py-2 text-sm font-semibold text-tx1 hover:bg-[#FEA0CE]/20"
                  @click="closeCalendarMenu"
                >Google Calendar</a>
                <button
                  type="button"
                  @click="downloadTrainCalendarFile"
                  class="block w-full text-left rounded-md px-3 py-2 text-sm font-semibold text-tx1 hover:bg-[#FEA0CE]/20"
                >Download .ics</button>
              </div>
            </details>
            <button
              v-if="train.cover_url"
              @click="downloadGraphic"
              class="btn-secondary text-sm flex items-center justify-center gap-1.5"
            >
              <ion-icon name="download-outline" aria-hidden="true"></ion-icon>
              Download Graphic
            </button>
            <button
              v-if="String(train.rules_md || '').trim()"
              @click="openRulesViewer"
              class="btn-secondary text-sm flex items-center justify-center gap-1.5"
            >
              <ion-icon name="document-text-outline" aria-hidden="true"></ion-icon>
              Rules &amp; Criteria
            </button>
          </div>
        </div>
      </div>

      <!-- Schedule -->
      <main data-tour="schedule-section" class="max-w-4xl mx-auto px-4 py-10 flex-1">
        <div v-for="(day, dayIdx) in days" :key="day.id" class="mb-12">
          <!-- 60s section header -->
          <div class="flex items-center gap-4 mb-4">
            <h2 class="font-display text-2xl sm:text-3xl text-tx1 shrink-0">
              {{ day.day_label ? `${day.day_label} — ` : '' }}{{ formatDate(day.day_date) }}
            </h2>
            <div class="flex-1 h-[3px] bg-niknax-600 rounded-full"></div>
          </div>
          <p class="text-tx3 text-xs font-mono mb-5 tracking-widest">ALL TIMES SHOWN · ET IS PRIMARY</p>

          <!-- Mobile slot list -->
          <div class="md:hidden space-y-3">
            <div
              v-for="(slot, slotIdx) in slotsByDay[day.id] || []"
              :key="slot.id"
              :id="`slot-mobile-${slot.id}`"
              :data-tour="(dayIdx === 0 && slotIdx === 0) ? 'first-slot-row' : undefined"
              :class="[
                recentlyChangedSlotIds.has(slot.id) ? 'slot-row-flash' : '',
                slot.id === activeSlotId
                  ? 'bg-[var(--badge-live-bg)] ring-1 ring-inset ring-[var(--badge-live-dot)]'
                  : slot.is_pre_assigned
                    ? 'bg-niknax-500/10'
                    : '',
              ]"
              class="border border-bd rounded-xl p-4 transition-colors"
            >
              <div class="flex items-start justify-between gap-3 mb-3">
                <div class="min-w-0">
                  <p class="text-xs text-tx3 mb-1">Slot {{ slotRowNumber(slot, slotIdx) }}</p>
                  <div class="flex items-center gap-2 flex-wrap">
                    <span v-if="slot.username" class="inline-flex items-center gap-1.5 flex-wrap">
                      <span class="font-medium text-tx1 break-words">{{ slot.username }}</span>
                      <span
                        v-if="memberBadge(slot.username)"
                        :class="memberBadgeClass(memberBadge(slot.username))"
                        class="text-[0.62rem] font-extrabold uppercase tracking-wide px-1.5 py-0.5 rounded-full"
                      >{{ memberBadge(slot.username) }}</span>
                    </span>
                    <span v-else class="text-tx3 italic text-sm">— available —</span>
                    <span
                      v-if="slot.id === activeSlotId"
                      class="inline-flex items-center gap-1 text-xs font-bold px-2 py-0.5 rounded-full bg-[var(--badge-live-bg)] text-[var(--badge-live-text)]"
                    >
                      <span class="w-1.5 h-1.5 rounded-full bg-[var(--badge-live-dot)] animate-pulse inline-block"></span>
                      LIVE NOW
                    </span>
                    <span
                      v-if="displaySlotLabel(slot)"
                      class="text-xs font-semibold text-niknax-500 bg-niknax-500/15 px-1.5 py-0.5 rounded"
                    >{{ displaySlotLabel(slot) }}</span>
                  </div>
                </div>
                <p class="text-tx1 font-bold text-lg shrink-0">{{ zones(slot.start_time)[0].time }}</p>
              </div>

              <div class="grid grid-cols-3 gap-2 text-sm mb-4">
                <div>
                  <p class="text-xs text-tx3">CT</p>
                  <p class="font-semibold text-tx2">{{ zones(slot.start_time)[1].time }}</p>
                </div>
                <div>
                  <p class="text-xs text-tx3">MT</p>
                  <p class="font-semibold text-tx2">{{ zones(slot.start_time)[2].time }}</p>
                </div>
                <div>
                  <p class="text-xs text-tx3">PT</p>
                  <p class="font-semibold text-tx2">{{ zones(slot.start_time)[3].time }}</p>
                </div>
              </div>

              <button
                v-if="canAttemptSignup && !slot.username"
                @click="openSignup(slot, day)"
                :data-tour="slot.id === firstOpenSlotId ? 'first-signup-btn' : undefined"
                class="w-full bg-niknax-600 hover:bg-niknax-500 text-white text-sm font-semibold px-3 py-2 rounded-lg transition-colors"
              >
                {{ !train.published || isKickoffSlot(slot) || slot.is_pre_assigned ? 'Moderator Sign Up' : 'Sign Up' }}
              </button>

              <template v-else-if="slot.username">
                <div v-if="slot.seller_link" class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <a
                    :href="safeUrl(slot.seller_link)"
                    target="_blank"
                    rel="noopener"
                    class="block w-full text-center whitespace-nowrap bg-niknax-600 hover:bg-niknax-500 text-white text-sm font-semibold px-3 py-2 rounded-lg transition-colors"
                  >Show Link ↗</a>
                  <details class="calendar-menu relative">
                    <summary class="list-none cursor-pointer block w-full text-center whitespace-nowrap bg-[#FEA0CE] hover:bg-[#F9927C] text-[#2A2118] text-sm font-semibold px-3 py-2 rounded-lg transition-colors">
                      Add to Calendar
                    </summary>
                    <div class="mt-1 sm:absolute sm:right-0 sm:z-20 sm:w-44 bg-surface border-2 border-[#FEA0CE] rounded-lg p-1 shadow-lg shadow-[#FEA0CE]/20">
                      <a
                        :href="googleCalendarUrl(day, slot)"
                        target="_blank"
                        rel="noopener"
                        class="block rounded-md px-3 py-2 text-sm font-semibold text-tx1 hover:bg-[#FEA0CE]/20"
                        @click="closeCalendarMenu"
                      >Google Calendar</a>
                      <button
                        type="button"
                        @click="downloadCalendarFile(day, slot, $event)"
                        class="block w-full text-left rounded-md px-3 py-2 text-sm font-semibold text-tx1 hover:bg-[#FEA0CE]/20"
                      >Download .ics</button>
                    </div>
                  </details>
                </div>

                <button
                  v-else-if="linkEditSlotId !== slot.id"
                  @click="startAddLink(slot)"
                  class="w-full whitespace-nowrap bg-[#6fcb9f] hover:bg-[#59b88a] text-gray-900 text-sm font-semibold px-3 py-2 rounded-lg transition-colors"
                >+ Add Show Link</button>

                <div v-else class="space-y-2">
                  <input
                    v-model="linkEditValue"
                    type="url"
                    placeholder="https://districtapp.tv/… or https://niknax.net/…"
                    class="input text-sm"
                    :disabled="linkSavingSlotId === slot.id"
                    @keyup.enter="saveLink(slot)"
                    @keyup.esc="cancelAddLink"
                  />
                  <div class="flex flex-col-reverse sm:flex-row gap-2">
                    <button
                      @click="cancelAddLink"
                      :disabled="linkSavingSlotId === slot.id"
                      class="btn-secondary text-sm w-full disabled:opacity-50"
                    >Cancel</button>
                    <button
                      @click="saveLink(slot)"
                      :disabled="linkSavingSlotId === slot.id"
                      class="btn-primary text-sm w-full disabled:opacity-50"
                    >
                      {{ linkSavingSlotId === slot.id ? 'Saving…' : 'Save' }}
                    </button>
                  </div>
                  <p v-if="linkEditError" class="text-red-600 dark:text-red-400 text-xs">
                    {{ linkEditError }}
                  </p>
                </div>
              </template>
            </div>
          </div>

          <!-- Desktop schedule table -->
          <div class="hidden md:block overflow-x-auto">
            <table class="w-full text-sm min-w-[680px]">
              <thead>
                <tr class="bg-sur2 text-tx3">
                  <th class="text-left px-4 py-3 w-8">#</th>
                  <th class="text-left px-4 py-3">Seller</th>
                  <th class="text-left px-4 py-3 font-semibold text-niknax-500">ET</th>
                  <th class="text-left px-4 py-3">CT</th>
                  <th class="text-left px-4 py-3">MT</th>
                  <th class="text-left px-4 py-3">PT</th>
                  <th class="text-left px-4 py-3 w-56"></th>
                </tr>
              </thead>
              <tbody class="divide-y divide-bd">
                <tr
                  v-for="(slot, slotIdx) in slotsByDay[day.id] || []"
                  :key="slot.id"
                  :id="`slot-desktop-${slot.id}`"
                  :data-tour="(dayIdx === 0 && slotIdx === 0) ? 'first-slot-row' : undefined"
                  :class="[
                    recentlyChangedSlotIds.has(slot.id) ? 'slot-row-flash' : '',
                    slot.id === activeSlotId
                      ? 'bg-[var(--badge-live-bg)] ring-1 ring-inset ring-[var(--badge-live-dot)]'
                      : slot.is_pre_assigned
                        ? 'bg-niknax-500/10'
                        : !slot.username ? 'hover:bg-sur2/60' : '',
                  ]"
                  class="transition-colors"
                >
                  <td class="px-4 py-3 text-tx3 text-xs">{{ slotRowNumber(slot, slotIdx) }}</td>
                  <td class="px-4 py-3">
                    <div class="flex items-center gap-2 flex-wrap">
                      <span v-if="slot.username" class="inline-flex items-center gap-1.5 flex-wrap">
                        <span class="font-medium text-tx1">{{ slot.username }}</span>
                        <span
                          v-if="memberBadge(slot.username)"
                          :class="memberBadgeClass(memberBadge(slot.username))"
                          class="text-[0.62rem] font-extrabold uppercase tracking-wide px-1.5 py-0.5 rounded-full"
                        >{{ memberBadge(slot.username) }}</span>
                      </span>
                      <span v-else class="text-tx3 italic text-xs">— available —</span>
                      <span
                        v-if="slot.id === activeSlotId"
                        class="inline-flex items-center gap-1 text-xs font-bold px-2 py-0.5 rounded-full bg-[var(--badge-live-bg)] text-[var(--badge-live-text)]"
                      >
                        <span class="w-1.5 h-1.5 rounded-full bg-[var(--badge-live-dot)] animate-pulse inline-block"></span>
                        LIVE NOW
                      </span>
                      <span
                        v-if="displaySlotLabel(slot)"
                        class="text-xs font-semibold text-niknax-500 bg-niknax-500/15 px-1.5 py-0.5 rounded"
                      >{{ displaySlotLabel(slot) }}</span>
                    </div>
                  </td>
                  <td class="px-4 py-3 text-tx1 font-bold text-base">{{ zones(slot.start_time)[0].time }}</td>
                  <td class="px-4 py-3 text-tx2 font-semibold">{{ zones(slot.start_time)[1].time }}</td>
                  <td class="px-4 py-3 text-tx2 font-semibold">{{ zones(slot.start_time)[2].time }}</td>
                  <td class="px-4 py-3 text-tx2 font-semibold">{{ zones(slot.start_time)[3].time }}</td>
                  <td class="px-4 py-3 text-right">
                    <button
                      v-if="canAttemptSignup && !slot.username"
                      @click="openSignup(slot, day)"
                      :data-tour="slot.id === firstOpenSlotId ? 'first-signup-btn' : undefined"
                      class="bg-niknax-600 hover:bg-niknax-500 text-white text-xs font-semibold px-3 py-1.5 rounded-lg transition-colors"
                    >
                      {{ !train.published || isKickoffSlot(slot) || slot.is_pre_assigned ? 'Moderator Sign Up' : 'Sign Up' }}
                    </button>

                    <template v-else-if="slot.username">
                      <div v-if="slot.seller_link" class="flex items-center justify-end gap-2">
                        <a
                          :href="safeUrl(slot.seller_link)"
                          target="_blank"
                          rel="noopener"
                          class="inline-flex items-center whitespace-nowrap bg-niknax-600 hover:bg-niknax-500 text-white text-xs font-semibold px-3 py-1.5 rounded-lg transition-colors"
                        >Show Link ↗</a>
                        <details class="calendar-menu relative">
                          <summary class="list-none cursor-pointer inline-flex items-center whitespace-nowrap bg-[#FEA0CE] hover:bg-[#F9927C] text-[#2A2118] text-xs font-semibold px-3 py-1.5 rounded-lg transition-colors">
                            Add to Calendar
                          </summary>
                          <div class="absolute right-0 z-20 mt-1 w-44 bg-surface border-2 border-[#FEA0CE] rounded-lg p-1 text-left shadow-lg shadow-[#FEA0CE]/20">
                            <a
                              :href="googleCalendarUrl(day, slot)"
                              target="_blank"
                              rel="noopener"
                              class="block rounded-md px-3 py-2 text-xs font-semibold text-tx1 hover:bg-[#FEA0CE]/20"
                              @click="closeCalendarMenu"
                            >Google Calendar</a>
                            <button
                              type="button"
                              @click="downloadCalendarFile(day, slot, $event)"
                              class="block w-full text-left rounded-md px-3 py-2 text-xs font-semibold text-tx1 hover:bg-[#FEA0CE]/20"
                            >Download .ics</button>
                          </div>
                        </details>
                      </div>

                      <button
                        v-else-if="linkEditSlotId !== slot.id"
                        @click="startAddLink(slot)"
                        class="whitespace-nowrap bg-[#6fcb9f] hover:bg-[#59b88a] text-gray-900 text-xs font-semibold px-3 py-1.5 rounded-lg transition-colors"
                      >+ Add Show Link</button>

                      <div v-else class="space-y-1">
                        <div class="flex items-center gap-1.5 justify-end">
                          <input
                            v-model="linkEditValue"
                            type="url"
                            placeholder="https://districtapp.tv/… or https://niknax.net/…"
                            class="input text-xs py-1 px-2 w-40"
                            :disabled="linkSavingSlotId === slot.id"
                            @keyup.enter="saveLink(slot)"
                            @keyup.esc="cancelAddLink"
                          />
                          <button
                            @click="saveLink(slot)"
                            :disabled="linkSavingSlotId === slot.id"
                            class="text-xs font-semibold text-niknax-600 dark:text-niknax-400 shrink-0 disabled:opacity-50"
                          >
                            {{ linkSavingSlotId === slot.id ? 'Saving…' : 'Save' }}
                          </button>
                          <button
                            @click="cancelAddLink"
                            :disabled="linkSavingSlotId === slot.id"
                            class="text-xs text-tx3 shrink-0 disabled:opacity-50"
                          >✕</button>
                        </div>
                        <p v-if="linkEditError" class="text-red-600 dark:text-red-400 text-xs text-right">
                          {{ linkEditError }}
                        </p>
                      </div>
                    </template>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

      </main>
    </template>

    <div v-else class="text-center py-32 text-tx3 flex-1">Event not found.</div>

    <!-- ── Bottom accent stripe ── -->
    <div class="h-3 bg-niknax-600 shrink-0 mt-auto"></div>

    <!-- ── Rules & Criteria acknowledgment modal (public signup gate) ── -->
    <Teleport to="body">
      <div
        v-if="rulesModal"
        class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 px-4"
        @click.self="rulesModal = null"
      >
        <div
          ref="rulesModalRef"
          class="bg-surface border border-bd rounded-2xl w-full max-w-lg shadow-2xl flex flex-col max-h-[85vh]"
          role="dialog"
          aria-modal="true"
          aria-labelledby="rules-modal-title"
          tabindex="-1"
        >
          <div class="px-6 pt-6 pb-3 border-b border-bd shrink-0">
            <h3 id="rules-modal-title" class="text-lg font-bold text-tx1">Sign-Up Rules &amp; Criteria</h3>
            <p class="text-tx3 text-sm mt-1">Please read everything below before signing up.</p>
          </div>

          <div
            ref="rulesScrollRef"
            class="rules-content overflow-y-auto px-6 py-4 flex-1"
            data-no-autofocus
            @scroll="onRulesScroll"
          >
            <div v-html="renderedRulesMd"></div>
          </div>

          <div class="px-6 py-4 border-t border-bd shrink-0 space-y-3">
            <p v-if="!rulesScrolledToEnd" class="text-xs text-tx3" aria-live="polite">
              Scroll to the end to continue.
            </p>
            <label v-else class="flex items-start gap-2 text-sm text-tx2 cursor-pointer">
              <input
                v-model="rulesAcknowledged"
                type="checkbox"
                class="rounded mt-0.5"
              />
              <span>I have read and understood the rules and criteria above.</span>
            </label>
            <div class="flex flex-col-reverse sm:flex-row gap-3">
              <button @click="rulesModal = null" class="btn-secondary sm:flex-1">Cancel</button>
              <button
                @click="confirmRulesAndProceed"
                :disabled="!rulesAcknowledged"
                class="btn-primary sm:flex-1"
              >Continue to Sign Up</button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Rules & Criteria viewer (plain read-only, no acknowledgment gate) ── -->
    <Teleport to="body">
      <div
        v-if="rulesViewerOpen"
        class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 px-4"
        @click.self="rulesViewerOpen = false"
      >
        <div
          ref="rulesViewerModalRef"
          class="bg-surface border border-bd rounded-2xl w-full max-w-lg shadow-2xl flex flex-col max-h-[85vh]"
          role="dialog"
          aria-modal="true"
          aria-labelledby="rules-viewer-title"
          tabindex="-1"
        >
          <div class="px-6 pt-6 pb-3 border-b border-bd shrink-0 flex items-start justify-between gap-4">
            <h3 id="rules-viewer-title" class="text-lg font-bold text-tx1">Sign-Up Rules &amp; Criteria</h3>
            <button @click="rulesViewerOpen = false" class="text-tx3 hover:text-tx1 text-xl leading-none" aria-label="Close">✕</button>
          </div>

          <div class="rules-content overflow-y-auto px-6 py-4 flex-1" data-no-autofocus>
            <div v-html="renderedRulesMd"></div>
          </div>

          <div class="px-6 py-4 border-t border-bd shrink-0">
            <button @click="rulesViewerOpen = false" class="btn-secondary w-full">Close</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── Signup Modal ── -->
    <Teleport to="body">
      <div
        v-if="signupModal"
        class="fixed inset-0 bg-black/70 flex items-center justify-center z-50 px-4"
        @click.self="signupModal = null"
      >
        <div
          ref="modalRef"
          class="bg-surface border border-bd rounded-2xl p-6 w-full max-w-sm shadow-2xl"
          role="dialog"
          aria-modal="true"
          :aria-label="signupSuccess ? 'Signup confirmed' : 'Sign up for this slot'"
          tabindex="-1"
        >

          <!-- ── Success state ── -->
          <template v-if="signupSuccess">
            <div class="text-center mb-5">
              <div class="text-5xl mb-3" aria-hidden="true">🎉</div>
              <h3 ref="successHeadingRef" tabindex="-1" class="text-xl font-bold text-white mb-1">You're on the train!</h3>
              <p class="text-gray-400 text-sm">
                {{ signupSuccess.username }} · {{ zones(signupSuccess.slot.start_time)[0].time }} ET
                · {{ formatDate(signupSuccess.day.day_date) }}
              </p>
            </div>

            <!-- Graphic download card -->
            <div v-if="train.cover_url" class="bg-gray-800 rounded-xl overflow-hidden mb-5">
              <img :src="train.cover_url" class="w-full object-cover max-h-48" :alt="`${train.name} promotional graphic`" />
              <div class="p-3 flex items-center justify-between gap-3">
                <div>
                  <p class="text-white text-sm font-semibold">Train Graphic</p>
                  <p class="text-gray-400 text-xs">Share with your followers!</p>
                </div>
                <button
                  @click="downloadGraphic"
                  class="btn-primary text-sm py-1.5 shrink-0 flex items-center gap-1.5"
                >
                  <ion-icon name="download-outline" aria-hidden="true"></ion-icon>
                  Download
                </button>
              </div>
            </div>

            <button @click="signupModal = null; signupSuccess = null" class="btn-secondary w-full">
              Close
            </button>
          </template>

          <!-- ── Input state ── -->
          <template v-else>
            <h3 class="text-lg font-bold text-tx1 mb-1">Sign Up for This Slot</h3>
            <p class="text-tx3 text-sm mb-5">
              {{ zones(signupModal.slot.start_time)[0].time }} ET
              · {{ signupModal.slot.duration_min }} min
              · {{ formatDate(signupModal.day.day_date) }}
            </p>

            <div class="space-y-4">
              <div class="relative">
                <label class="label" id="signup-username-label">Your District / Niknax Username *</label>
                <input
                  v-model="signupUsername"
                  class="input"
                  placeholder="@YourUsername"
                  autocomplete="off"
                  role="combobox"
                  aria-autocomplete="list"
                  aria-haspopup="listbox"
                  :aria-expanded="usernameSuggestions.length > 0"
                  aria-controls="username-suggestions-list"
                  :aria-activedescendant="activeSuggestion >= 0 ? `username-suggestion-${activeSuggestion}` : undefined"
                  aria-labelledby="signup-username-label"
                  @input="onUsernameInput"
                  @keyup.enter="submitSignup"
                  @keydown.down.prevent="moveSuggestion(1)"
                  @keydown.up.prevent="moveSuggestion(-1)"
                  @keydown.esc="onUsernameEscape"
                  @blur="hideSuggestionsSoon"
                  @focus="onUsernameInput"
                />
                <ul
                  v-if="usernameSuggestions.length"
                  id="username-suggestions-list"
                  role="listbox"
                  class="absolute z-10 left-0 right-0 mt-1 card p-1 max-h-48 overflow-y-auto shadow-lg"
                >
                  <li
                    v-for="(s, i) in usernameSuggestions"
                    :id="`username-suggestion-${i}`"
                    :key="s"
                    role="option"
                    :aria-selected="i === activeSuggestion"
                    class="px-3 py-1.5 rounded-md text-sm cursor-pointer"
                    :class="i === activeSuggestion ? 'bg-niknax-600 text-white' : 'text-tx1 hover:bg-sur2'"
                    @mousedown.prevent="pickSuggestion(s)"
                  >
                    @{{ s }}
                  </li>
                </ul>
              </div>
            </div>

            <p class="text-red-600 dark:text-red-400 text-sm mt-3 min-h-[1.25rem]" aria-live="polite">{{ signupError }}</p>

            <div class="flex flex-col-reverse sm:flex-row gap-3 mt-6">
              <button @click="signupModal = null" class="btn-secondary sm:flex-1">Cancel</button>
              <button @click="submitSignup" :disabled="signingUp" class="btn-primary sm:flex-1">
                {{ signingUp ? 'Saving…' : 'Claim Slot ✓' }}
              </button>
            </div>
          </template>

        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue'
import { RouterLink, useRoute } from 'vue-router'
import { supabase } from '../../lib/supabase.js'
import { allZones, formatDate, parseTime, trainStatus, STATUS_BADGE_CLASS, isPastTrain } from '../../lib/timeUtils.js'
import { useThemeStore } from '../../stores/theme.js'
import { useOnboardingStore } from '../../stores/onboarding.js'
import { useModalA11y } from '../../composables/useModalA11y.js'
import { renderMarkdown } from '../../lib/renderMarkdown.js'

const route = useRoute()
const theme = useThemeStore()
const onboarding = useOnboardingStore()

const train   = ref(null)
const days    = ref([])
const slots   = ref([])
const loading = ref(true)
const memberRoles = ref({})
const recentlyChangedSlotIds = ref(new Set())

const signupModal    = ref(null)
const signupSuccess  = ref(null)   // { username, slot, day } after successful claim
const signupUsername = ref('')
const signupError    = ref('')
const signingUp      = ref(false)
const pageLinkCopied = ref(false)

// ── Rules & criteria acknowledgment gate (public signup only) ────────────
const rulesModal        = ref(null)   // { slot, day } pending acknowledgment
const rulesScrollRef    = ref(null)
const rulesScrolledToEnd = ref(false)
const rulesAcknowledged  = ref(false)

const renderedRulesMd = computed(() => renderMarkdown(train.value?.rules_md || ''))

const { modalRef: rulesModalRef } = useModalA11y(
  () => !!rulesModal.value,
  () => { rulesModal.value = null }
)

function onRulesScroll() {
  const el = rulesScrollRef.value
  if (!el) return
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - 16) {
    rulesScrolledToEnd.value = true
  }
}

function confirmRulesAndProceed() {
  if (!rulesAcknowledged.value) return
  const { slot, day } = rulesModal.value
  rulesModal.value = null
  beginSignup(slot, day)
}

// Plain "view the rules anytime" button — no scroll/acknowledge requirement,
// just a read-only look at the same content shown in the signup gate.
const rulesViewerOpen = ref(false)
const { modalRef: rulesViewerModalRef } = useModalA11y(
  () => rulesViewerOpen.value,
  () => { rulesViewerOpen.value = false }
)
function openRulesViewer() {
  rulesViewerOpen.value = true
}

// ── Inline "add show link" editing for already-claimed slots ─────────────
const linkEditSlotId = ref(null)
const linkEditValue  = ref('')
const linkEditError  = ref('')
const linkSavingSlotId = ref(null)
let slotsChannel = null
let trainChannel = null
let rowSoundCtx = null

function startAddLink(slot) {
  linkEditSlotId.value = slot.id
  linkEditValue.value  = slot.seller_link || ''
  linkEditError.value  = ''
}

function cancelAddLink() {
  linkEditSlotId.value = null
  linkEditValue.value  = ''
  linkEditError.value  = ''
}

async function saveLink(slot) {
  const value = normalizePublicUrl(linkEditValue.value)
  if (linkEditValue.value.trim() && !value) {
    linkEditError.value = 'Please enter a valid https:// District or Niknax link.'
    return
  }

  linkSavingSlotId.value = slot.id
  linkEditError.value = ''

  try {
    const { data, error } = await supabase.rpc('set_slot_seller_link', {
      slot_id: slot.id,
      link: value,
    })
    if (error) throw error

    const savedLink = data?.seller_link || value || null
    const idx = slots.value.findIndex(s => s.id === slot.id)
    if (idx !== -1) slots.value[idx].seller_link = savedLink
    slot.seller_link = savedLink
    cancelAddLink()
  } catch (err) {
    linkEditError.value = err?.message || 'Could not save show link.'
  } finally {
    linkSavingSlotId.value = null
  }
}

const successHeadingRef = ref(null)

const { modalRef } = useModalA11y(
  () => !!signupModal.value,
  () => { signupModal.value = null }
)

watch(signupSuccess, async (val) => {
  if (val) {
    await nextTick()
    successHeadingRef.value?.focus?.()
  }
})

watch(
  () => [...new Set(slots.value.map(slot => usernameKey(slot.username)).filter(Boolean))].sort().join('|'),
  loadMemberBadges
)

// ── Username autocomplete (from members_signup_search view) ──────────────
const usernameSuggestions = ref([])
const activeSuggestion    = ref(-1)
let usernameTimer = null

function onUsernameInput() {
  clearTimeout(usernameTimer)
  const term = signupUsername.value.trim()
  if (term.length < 2) {
    usernameSuggestions.value = []
    return
  }
  usernameTimer = setTimeout(async () => {
    const { data, error } = await supabase
      .from('members_signup_search')
      .select('username')
      .ilike('username', `%${term}%`)
      .limit(8)
    if (!error) {
      usernameSuggestions.value = (data || []).map(r => r.username)
      activeSuggestion.value = -1
    }
  }, 250)
}

function pickSuggestion(username) {
  signupUsername.value = username
  usernameSuggestions.value = []
}

function onUsernameEscape(e) {
  // If the suggestion list is open, Escape should dismiss just the list
  // (not the whole signup modal). Stop it from bubbling to the modal's
  // document-level Escape-to-close handler.
  if (usernameSuggestions.value.length) {
    e.stopPropagation()
    usernameSuggestions.value = []
    activeSuggestion.value = -1
  }
}

function moveSuggestion(delta) {
  if (!usernameSuggestions.value.length) return
  const max = usernameSuggestions.value.length - 1
  let next = activeSuggestion.value + delta
  if (next < 0) next = max
  if (next > max) next = 0
  activeSuggestion.value = next
  signupUsername.value = usernameSuggestions.value[next]
}

function hideSuggestionsSoon() {
  setTimeout(() => { usernameSuggestions.value = [] }, 150)
}

function zones(t) { return allZones(t) }

function isKickoffSlot(slot) {
  return String(slot?.label || '').trim().toLowerCase() === 'kickoff'
}

function displaySlotLabel(slot) {
  const label = String(slot?.label || '').trim()
  return label.toLowerCase() === 'niknax boost' ? '' : label
}

function slotRowNumber(slot, idx) {
  return isKickoffSlot(slot) ? 0 : Math.max(1, Number(slot?.slot_order ?? idx + 1))
}

function normalizePublicUrl(raw) {
  const value = raw.trim()
  if (!value) return null
  try {
    const url = new URL(value)
    const host = url.hostname.toLowerCase()
    if (url.protocol !== 'https:') return null
    const allowedHosts = ['districtapp.tv', 'niknax.net']
    if (!allowedHosts.some(domain => host === domain || host.endsWith(`.${domain}`))) return null
    return url.toString()
  } catch {
    return null
  }
}

function safeUrl(raw) {
  return normalizePublicUrl(raw) || '#'
}

function applySlotRealtimeChange(payload) {
  const nextSlot = payload.new
  const oldSlot = payload.old

  if (payload.eventType === 'DELETE') {
    slots.value = slots.value.filter(slot => slot.id !== oldSlot?.id)
    playRowChangeSound()
    return
  }

  if (!nextSlot?.id) return
  flashSlotRow(nextSlot.id)
  playRowChangeSound()
  const idx = slots.value.findIndex(slot => slot.id === nextSlot.id)
  if (idx === -1) {
    slots.value.push(nextSlot)
  } else {
    slots.value[idx] = { ...slots.value[idx], ...nextSlot }
  }
}

function usernameKey(username) {
  return String(username || '').trim().replace(/^@+/, '').toLowerCase()
}

function memberBadge(username) {
  return memberRoles.value[usernameKey(username)] || ''
}

function memberBadgeClass(label) {
  const key = String(label || '').trim().toLowerCase()
  if (key === 'nn owner') return 'bg-[#FEA0CE] text-[#2A2118]'
  if (key === 'nn admin') return 'bg-[#A8401F] text-white'
  if (key === 'nn moderator') return 'bg-niknax-600 text-white'
  return 'bg-olive-600 text-white'
}

function shouldShowMemberBadge(label) {
  return ['nn owner', 'nn admin', 'nn moderator'].includes(String(label || '').trim().toLowerCase())
}

async function loadMemberBadges() {
  const keys = [...new Set(slots.value.map(slot => usernameKey(slot.username)).filter(Boolean))]
  if (!keys.length) {
    memberRoles.value = {}
    return
  }

  const { data, error } = await supabase
    .from('members_public_badges')
    .select('username_key, role')
    .in('username_key', keys)

  if (error) return

  const nextRoles = {}
  for (const member of data || []) {
    if (shouldShowMemberBadge(member.role)) nextRoles[member.username_key] = member.role
  }
  memberRoles.value = nextRoles
}

function flashSlotRow(slotId) {
  recentlyChangedSlotIds.value = new Set([...recentlyChangedSlotIds.value, slotId])
  setTimeout(() => {
    const nextIds = new Set(recentlyChangedSlotIds.value)
    nextIds.delete(slotId)
    recentlyChangedSlotIds.value = nextIds
  }, 1800)
}

async function playRowChangeSound() {
  if (theme.isSoundMuted) return
  try {
    rowSoundCtx ||= new (window.AudioContext || window.webkitAudioContext)()
    if (rowSoundCtx.state === 'suspended') await rowSoundCtx.resume()
    const t = rowSoundCtx.currentTime
    const notes = [660, 880]
    notes.forEach((freq, idx) => {
      const osc = rowSoundCtx.createOscillator()
      const gain = rowSoundCtx.createGain()
      osc.type = 'triangle'
      osc.frequency.setValueAtTime(freq, t + idx * 0.055)
      gain.gain.setValueAtTime(0, t + idx * 0.055)
      gain.gain.linearRampToValueAtTime(0.08, t + idx * 0.055 + 0.012)
      gain.gain.exponentialRampToValueAtTime(0.001, t + idx * 0.055 + 0.16)
      osc.connect(gain)
      gain.connect(rowSoundCtx.destination)
      osc.start(t + idx * 0.055)
      osc.stop(t + idx * 0.055 + 0.18)
    })
  } catch {}
}

function subscribeToSlotChanges(dayIds) {
  if (!dayIds.length) return
  if (slotsChannel) supabase.removeChannel(slotsChannel)

  slotsChannel = supabase
    .channel(`public-train-slots-${route.params.id}`)
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'slots',
        filter: `train_day_id=in.(${dayIds.join(',')})`,
      },
      applySlotRealtimeChange
    )
    .subscribe()
}

function applyTrainRealtimeChange(payload) {
  const nextTrain = payload.new
  if (!nextTrain?.id) return
  train.value = { ...train.value, ...nextTrain }
}

function subscribeToTrainChanges(trainId) {
  if (!trainId) return
  if (trainChannel) supabase.removeChannel(trainChannel)

  trainChannel = supabase
    .channel(`public-train-${trainId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'trains',
        filter: `id=eq.${trainId}`,
      },
      applyTrainRealtimeChange
    )
    .subscribe()
}

function slotCalendarDate(day, slot, offsetMinutes = 0) {
  const [year, month, date] = day.day_date.split('-').map(Number)
  const { hours, minutes } = parseTime(slot.start_time)
  return new Date(year, month - 1, date, hours, minutes + offsetMinutes)
}

function calendarStamp(date) {
  return [
    date.getFullYear(),
    String(date.getMonth() + 1).padStart(2, '0'),
    String(date.getDate()).padStart(2, '0'),
    'T',
    String(date.getHours()).padStart(2, '0'),
    String(date.getMinutes()).padStart(2, '0'),
    '00',
  ].join('')
}

function utcCalendarStamp(date) {
  return [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, '0'),
    String(date.getUTCDate()).padStart(2, '0'),
    'T',
    String(date.getUTCHours()).padStart(2, '0'),
    String(date.getUTCMinutes()).padStart(2, '0'),
    String(date.getUTCSeconds()).padStart(2, '0'),
    'Z',
  ].join('')
}

function calendarTitle(slot) {
  const seller = slot.username ? `@${slot.username}` : 'Seller'
  return `${seller} on ${train.value?.name || 'Niknax Train'}`
}

function calendarDescription(slot) {
  const link = safeUrl(slot.seller_link)
  return [
    `Live show link: ${link}`,
    '',
    `Part of ${train.value?.name || 'Niknax Train Station'}.`,
  ].join('\n')
}

function googleCalendarUrl(day, slot) {
  const start = slotCalendarDate(day, slot)
  const end = slotCalendarDate(day, slot, slot.duration_min || 30)
  const params = new URLSearchParams({
    action: 'TEMPLATE',
    text: calendarTitle(slot),
    dates: `${calendarStamp(start)}/${calendarStamp(end)}`,
    ctz: 'America/New_York',
    details: calendarDescription(slot),
    location: safeUrl(slot.seller_link),
  })
  return `https://calendar.google.com/calendar/render?${params.toString()}`
}

const trainCalendarRange = computed(() => {
  const entries = flatSlotsChrono.value
    .map(({ day, slot }) => ({
      start: slotCalendarDate(day, slot),
      end: slotCalendarDate(day, slot, slot.duration_min || 30),
    }))
    .sort((a, b) => a.start - b.start)

  if (!entries.length) return null
  return {
    start: entries[0].start,
    end: entries.reduce((latest, entry) => entry.end > latest ? entry.end : latest, entries[0].end),
  }
})

const trainCalendarTitle = computed(() =>
  `${train.value?.name || 'Niknax Train'} Reminder`
)

const trainCalendarDescription = computed(() => {
  const lines = [
    train.value?.tagline || '',
    train.value?.description || '',
    `Event page: ${location.href}`,
  ]
  if (effectiveDistrictLink.value) lines.push(`Watch link: ${effectiveDistrictLink.value}`)
  return lines.filter(Boolean).join('\n\n')
})

const googleTrainCalendarUrl = computed(() => {
  if (!trainCalendarRange.value) return '#'
  const params = new URLSearchParams({
    action: 'TEMPLATE',
    text: trainCalendarTitle.value,
    dates: `${calendarStamp(trainCalendarRange.value.start)}/${calendarStamp(trainCalendarRange.value.end)}`,
    ctz: 'America/New_York',
    details: trainCalendarDescription.value,
    location: location.href,
  })
  return `https://calendar.google.com/calendar/render?${params.toString()}`
})

function escapeIcsText(value) {
  return String(value)
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\r?\n/g, '\\n')
}

function closeCalendarMenu(event) {
  const menu = event?.currentTarget?.closest?.('details')
  if (menu) menu.open = false
}

function closeCalendarMenusOnOutsideClick(event) {
  if (event.target?.closest?.('.calendar-menu')) return
  for (const menu of document.querySelectorAll('.calendar-menu[open]')) {
    menu.open = false
  }
}

function downloadCalendarFile(day, slot, event) {
  const start = slotCalendarDate(day, slot)
  const end = slotCalendarDate(day, slot, slot.duration_min || 30)
  const now = new Date()
  const filename = `${calendarTitle(slot).replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase() || 'niknax-show'}.ics`
  const content = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Niknax//Train Station//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${slot.id}@niknax-trains`,
    `DTSTAMP:${utcCalendarStamp(now)}`,
    `DTSTART;TZID=America/New_York:${calendarStamp(start)}`,
    `DTEND;TZID=America/New_York:${calendarStamp(end)}`,
    `SUMMARY:${escapeIcsText(calendarTitle(slot))}`,
    `DESCRIPTION:${escapeIcsText(calendarDescription(slot))}`,
    `LOCATION:${escapeIcsText(safeUrl(slot.seller_link))}`,
    `URL:${safeUrl(slot.seller_link)}`,
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n')

  const blob = new Blob([`${content}\r\n`], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = Object.assign(document.createElement('a'), { href: url, download: filename })
  a.click()
  URL.revokeObjectURL(url)
  closeCalendarMenu(event)
}

function downloadTrainCalendarFile(event) {
  if (!trainCalendarRange.value) return
  const now = new Date()
  const filename = `${trainCalendarTitle.value.replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '').toLowerCase() || 'niknax-train'}.ics`
  const content = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Niknax//Train Station//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${train.value?.id || route.params.id}@niknax-trains`,
    `DTSTAMP:${utcCalendarStamp(now)}`,
    `DTSTART;TZID=America/New_York:${calendarStamp(trainCalendarRange.value.start)}`,
    `DTEND;TZID=America/New_York:${calendarStamp(trainCalendarRange.value.end)}`,
    `SUMMARY:${escapeIcsText(trainCalendarTitle.value)}`,
    `DESCRIPTION:${escapeIcsText(trainCalendarDescription.value)}`,
    `LOCATION:${escapeIcsText(location.href)}`,
    `URL:${location.href}`,
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n')

  const blob = new Blob([`${content}\r\n`], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = Object.assign(document.createElement('a'), { href: url, download: filename })
  a.click()
  URL.revokeObjectURL(url)
  closeCalendarMenu(event)
}

// ── Live-now tracking ─────────────────────────────────────────────────────
function getCurrentET() {
  return new Date(new Date().toLocaleString('en-US', { timeZone: 'America/New_York' }))
}

const nowET = ref(getCurrentET())
let clockInterval = null

const activeSlotId = computed(() => {
  const d = nowET.value
  const dateStr = [
    d.getFullYear(),
    String(d.getMonth() + 1).padStart(2, '0'),
    String(d.getDate()).padStart(2, '0'),
  ].join('-')
  const nowMin = d.getHours() * 60 + d.getMinutes()

  for (const day of days.value) {
    if (day.day_date !== dateStr) continue
    for (const slot of (slotsByDay.value[day.id] || [])) {
      const { hours, minutes } = parseTime(slot.start_time)
      const startMin = hours * 60 + minutes
      const endMin   = startMin + (slot.duration_min || 30)
      if (nowMin >= startMin && nowMin < endMin) return slot.id
    }
  }
  return null
})

const trainIsPast = computed(() =>
  isPastTrain(days.value.map(d => d.day_date))
)

const status = computed(() => {
  if (trainIsPast.value) return { key: 'past', label: 'Past Event' }
  return trainStatus(train.value, slots.value.length, slots.value.filter(s => s.username).length)
})

const canAttemptSignup = computed(() =>
  !trainIsPast.value && !!(train.value?.published || train.value?.is_upcoming)
)

const slotsByDay = computed(() => {
  const map = {}
  for (const s of slots.value) {
    if (!map[s.train_day_id]) map[s.train_day_id] = []
    map[s.train_day_id].push(s)
  }
  for (const k in map) {
    map[k].sort((a, b) => a.slot_order - b.slot_order || a.start_time.localeCompare(b.start_time))
  }
  return map
})

// ── Dynamic "Watch on District" link ──────────────────────────────────────
// Always points at whichever seller should currently have eyes on them:
// the slot live right now, or — if nothing's live yet/anymore today — the
// next slot chronologically (which naturally rolls over to the next day's
// slot #1 once today's slots have all ended). If that anchor slot hasn't
// had its show link filled in yet, we walk forward to the next slot that
// has one. Falls back to the admin-set generic event link if nothing else
// is available (e.g. the whole event has wrapped).
const flatSlotsChrono = computed(() => {
  const list = []
  for (const day of days.value) {
    for (const slot of (slotsByDay.value[day.id] || [])) {
      list.push({ day, slot })
    }
  }
  return list
})

function slotEndsAt(day, slot) {
  const [y, m, d] = day.day_date.split('-').map(Number)
  const { hours, minutes } = parseTime(slot.start_time)
  const start = new Date(y, m - 1, d, hours, minutes)
  return new Date(start.getTime() + (slot.duration_min || 30) * 60000)
}

const firstOpenSlotId = computed(() => {
  const entry = flatSlotsChrono.value.find(
    ({ slot }) => canAttemptSignup.value && !slot.username && !slot.is_pre_assigned
  )
  return entry?.slot.id || null
})

// ── Signup walkthrough ────────────────────────────────────────────────────
function buildSignupSteps() {
  const steps = [
    {
      target: '[data-tour="first-slot-row"]',
      title: 'The Show Schedule',
      body: 'Each row is a time slot, shown in Eastern, Central, Mountain, and Pacific time.',
      placement: 'bottom',
    },
  ]

  if (firstOpenSlotId.value) {
    steps.push({
      target: '[data-tour="first-signup-btn"]',
      title: 'Grab an Open Slot',
      body: 'Rows marked "— available —" are up for grabs. Tap Sign Up to claim one — you\'ll be asked to read and accept the rules & criteria for this train before you can commit to a slot.',
      placement: 'left',
    })
  }

  steps.push({
    title: 'Enter Your Username',
    body: "You'll be asked for your District / Niknax username — type it in and tap Claim Slot ✓. Once you're on the train, an \"+ Add Show Link\" button appears on your row — create your show in District, then paste its link there. That link is what goes public while you're live!",
    placement: 'center',
  })

  steps.push({
    target: '[data-tour="share-button"]',
    title: 'Spread the Word',
    body: 'Use Share Event to grab a link for this train and post it anywhere.',
    placement: 'bottom',
  })

  return steps
}

function startSignupTour() {
  onboarding.start(buildSignupSteps())
}

const effectiveDistrictLink = computed(() => {
  const now = nowET.value
  const list = flatSlotsChrono.value
  const anchorIdx = list.findIndex(({ day, slot }) => slotEndsAt(day, slot) > now)
  if (anchorIdx === -1) return normalizePublicUrl(train.value?.district_link || '')

  for (let i = anchorIdx; i < list.length; i++) {
    const link = normalizePublicUrl(list[i].slot.seller_link || '')
    if (link) return link
  }
  return normalizePublicUrl(train.value?.district_link || '')
})

async function load() {
  loading.value = true
  const id = route.params.id

  const { data: t } = await supabase
    .from('trains')
    .select('*')
    .eq('id', id)
    .or('published.eq.true,is_upcoming.eq.true')
    .single()

  if (!t) { loading.value = false; return }
  train.value = t
  subscribeToTrainChanges(t.id)

  document.title = `${t.name} — Niknax Raid Train`
  setMeta('og:title', t.name)
  const metaDescription = t.tagline || 'Join the live-selling event on Niknax.net'
  setMeta('og:description', metaDescription)
  setNamedMeta('description', metaDescription)
  setNamedMeta('twitter:description', metaDescription)
  if (t.cover_url) setMeta('og:image', t.cover_url)
  setMeta('og:url', location.href)

  const { data: d } = await supabase
    .from('train_days')
    .select('*')
    .eq('train_id', id)
    .order('day_order')

  days.value = d || []

  if (days.value.length) {
    const dayIds = days.value.map(d => d.id)
    const { data: s } = await supabase
      .from('slots')
      .select('*')
      .in('train_day_id', dayIds)
      .order('slot_order')
    slots.value = s || []
    subscribeToSlotChanges(dayIds)
  }

  loading.value = false
}

function setMeta(name, content) {
  let el = document.querySelector(`meta[property="${name}"]`)
  if (!el) { el = document.createElement('meta'); el.setAttribute('property', name); document.head.appendChild(el) }
  el.setAttribute('content', content)
}

function setNamedMeta(name, content) {
  let el = document.querySelector(`meta[name="${name}"]`)
  if (!el) { el = document.createElement('meta'); el.setAttribute('name', name); document.head.appendChild(el) }
  el.setAttribute('content', content)
}

function openSignup(slot, day) {
  // Public signup gate: require sellers to scroll through and acknowledge
  // this train's rules/criteria before they can claim a slot. Admin-driven
  // actions (manual username entry, train edits) never go through here.
  if (String(train.value?.rules_md || '').trim()) {
    rulesScrolledToEnd.value = false
    rulesAcknowledged.value  = false
    rulesModal.value = { slot, day }
    nextTick(() => {
      const el = rulesScrollRef.value
      if (!el) return
      // Always start at the top — the modal's initial-focus handling skips
      // links inside this region (see data-no-autofocus / useModalA11y) so
      // this is now mostly a defensive reset, not a fix for the focus jump.
      el.scrollTop = 0
      // If the content is short enough to not need scrolling, don't block on it.
      if (el.scrollHeight <= el.clientHeight + 16) {
        rulesScrolledToEnd.value = true
      }
    })
    return
  }
  beginSignup(slot, day)
}

function beginSignup(slot, day) {
  signupSuccess.value  = null
  signupModal.value    = { slot, day }
  signupUsername.value = ''
  signupError.value    = ''
  usernameSuggestions.value = []
}

async function submitSignup() {
  if (!signupUsername.value.trim()) {
    signupError.value = 'Please enter your username.'
    return
  }
  signingUp.value   = true
  signupError.value = ''

  const { slot, day } = signupModal.value

  const { data, error } = await supabase.rpc('claim_slot', {
    slot_id: slot.id,
    claimant_username: signupUsername.value.trim(),
  })

  if (error) {
    signupError.value = error.message || 'Could not claim slot. Please try again.'
  } else {
    const idx = slots.value.findIndex(s => s.id === slot.id)
    if (idx !== -1) {
      slots.value[idx].username = data.username
    }
    // Show success screen with graphic download
    signupSuccess.value = { username: data.username, slot, day }
  }
  signingUp.value = false
}

async function downloadGraphic() {
  if (!train.value?.cover_url) return
  const filename = `${train.value.name.replace(/[^a-z0-9]/gi, '-').toLowerCase()}-train-graphic`
  try {
    const res  = await fetch(train.value.cover_url)
    const blob = await res.blob()
    const ext  = blob.type.includes('png') ? 'png' : blob.type.includes('gif') ? 'gif' : 'jpg'
    const url  = URL.createObjectURL(blob)
    const a    = Object.assign(document.createElement('a'), { href: url, download: `${filename}.${ext}` })
    a.click()
    URL.revokeObjectURL(url)
  } catch {
    // CORS blocked — open in new tab so user can save manually
    window.open(train.value.cover_url, '_blank')
  }
}

function copyPageLink() {
  navigator.clipboard.writeText(location.href)
  pageLinkCopied.value = true
  setTimeout(() => pageLinkCopied.value = false, 2000)
}

async function loadAndScroll() {
  document.addEventListener('pointerdown', closeCalendarMenusOnOutsideClick)
  await load()
  clockInterval = setInterval(() => { nowET.value = getCurrentET() }, 30_000)
  await nextTick()
  if (activeSlotId.value) {
    const slotPrefix = window.matchMedia('(min-width: 768px)').matches ? 'slot-desktop' : 'slot-mobile'
    document.getElementById(`${slotPrefix}-${activeSlotId.value}`)
      ?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  }
  // Continuing the walkthrough handed off from the Home page tour
  if (onboarding.consumeContinuation('signup')) {
    nextTick(() => startSignupTour())
  }
}

onMounted(loadAndScroll)
onUnmounted(() => {
  document.removeEventListener('pointerdown', closeCalendarMenusOnOutsideClick)
  if (clockInterval) clearInterval(clockInterval)
  if (slotsChannel) supabase.removeChannel(slotsChannel)
  if (trainChannel) supabase.removeChannel(trainChannel)
})
</script>
