<template>
  <div class="min-h-screen bg-base">
    <PublicNav />

    <main class="max-w-4xl mx-auto px-6 py-10">

      <!-- Loading -->
      <div v-if="loading" class="text-tx3 text-center py-20">Loading…</div>

      <!-- Not a member train -->
      <div v-else-if="!train || !train.is_member_train" class="card text-center py-16">
        <p class="text-tx1 text-lg mb-2">Train not found</p>
        <RouterLink to="/" class="btn-secondary mt-4">Back to home</RouterLink>
      </div>

      <!-- Access gate: email → emailed passcode -->
      <div v-else-if="!authToken" class="max-w-md mx-auto mt-12">
        <div class="card space-y-5">
          <div>
            <h1 class="text-xl font-semibold text-tx1">Conductor Access</h1>
            <p class="text-sm text-tx3 mt-1">
              Manage <strong class="text-tx2">{{ train.name }}</strong>.
            </p>
          </div>

          <form @submit.prevent="submitCode" class="space-y-4">
            <div>
              <label class="label" for="gate-code">Access code</label>
              <input
                id="gate-code"
                v-model="gateCode"
                autocomplete="off"
                autocapitalize="characters"
                spellcheck="false"
                maxlength="9"
                class="input text-center text-2xl tracking-[0.25em] font-mono uppercase"
                placeholder="XXXX-XXXX"
                required
                :disabled="gateLoading"
                @input="gateCode = formatCodeInput(gateCode)"
              />
              <p class="text-xs text-tx3 mt-1.5">
                The 8-character code from your Niknax admin. Codes are good for 48 hours —
                once you're in, you'll stay signed in on this device for 90 days.
              </p>
            </div>

            <p v-if="gateError" class="text-red-600 dark:text-red-400 text-sm" role="alert">{{ gateError }}</p>

            <button type="submit" :disabled="gateLoading || gateCode.length < 9" class="btn-primary w-full">
              {{ gateLoading ? 'Checking…' : 'Unlock train →' }}
            </button>
          </form>

          <p class="text-xs text-tx3 border-t border-bd pt-4">
            Don't have a code, or has yours expired? Ask the Niknax team for a new one.
          </p>
        </div>
      </div>

      <!-- Management UI -->
      <template v-else>
        <div class="flex items-center gap-3 mb-2 flex-wrap">
          <RouterLink to="/" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-sm">← All trains</RouterLink>
          <RouterLink :to="`/train/${train.id}`" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-sm" target="_blank">View public page ↗</RouterLink>
        </div>

        <!-- Status banner -->
        <div v-if="!train.published && !train.is_upcoming" class="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700 rounded-lg px-4 py-3 mb-6 flex items-start gap-2">
          <span class="text-amber-600 dark:text-amber-400 mt-0.5">⏳</span>
          <p class="text-sm text-amber-800 dark:text-amber-300">
            <strong>Pending review.</strong> The Niknax team will publish this train once it's approved. You can still edit your train details and schedule while it's pending.
          </p>
        </div>
        <!-- Status control — available once an admin has approved the train -->
        <div v-else class="card mb-6">
          <div class="flex items-start justify-between gap-4 flex-wrap">
            <div>
              <p class="text-sm font-semibold text-tx1 mb-0.5">Train Status</p>
              <p class="text-xs text-tx3">
                <template v-if="train.published">
                  Sellers can claim slots right now.
                </template>
                <template v-else>
                  Listed on the public schedule, but sign-ups aren't open yet.
                </template>
              </p>
            </div>

            <div class="flex rounded-lg border border-bd overflow-hidden shrink-0">
              <button
                @click="setStatus('upcoming')"
                :disabled="savingStatus"
                class="px-3.5 py-2 text-sm font-semibold transition-colors disabled:opacity-50"
                :class="train.is_upcoming
                  ? 'bg-amber-500 text-white'
                  : 'bg-surface text-tx3 hover:bg-sur2 hover:text-tx1'"
              >Arriving Soon</button>
              <button
                @click="setStatus('boarding')"
                :disabled="savingStatus"
                class="px-3.5 py-2 text-sm font-semibold border-l border-bd transition-colors disabled:opacity-50"
                :class="train.published
                  ? 'bg-green-600 text-white'
                  : 'bg-surface text-tx3 hover:bg-sur2 hover:text-tx1'"
              >Now Boarding</button>
            </div>
          </div>

          <p v-if="statusError" class="text-red-600 dark:text-red-400 text-sm mt-3">{{ statusError }}</p>
        </div>

        <div class="flex items-start justify-between gap-4 mb-8 flex-wrap">
          <div>
            <h1 class="text-2xl font-display font-bold text-tx1">{{ train.name }}</h1>
            <p v-if="train.tagline" class="text-tx3 mt-1">{{ train.tagline }}</p>
            <p class="text-xs text-tx3 mt-1">
              Signed in as <strong>{{ authEmail }}</strong>
              <span v-if="isPrimary"> · primary conductor</span>
            </p>
          </div>
          <div class="flex items-center gap-3 shrink-0">
            <button @click="signOutConductor" class="text-tx3 hover:text-tx1 text-sm">Sign out</button>
            <button
              v-if="isPrimary"
              @click="confirmDeleteTrain"
              :disabled="deleting"
              class="text-red-600 hover:text-red-500 dark:text-red-400 dark:hover:text-red-300 text-sm disabled:opacity-50"
            >{{ deleting ? 'Deleting…' : 'Delete Train' }}</button>
          </div>
        </div>

        <!-- Edit details -->
        <section class="card space-y-5 mb-8">
          <div class="flex items-center justify-between">
            <h2 class="text-base font-semibold text-tx1">Train Details</h2>
            <span v-if="detailsSaved" class="text-green-600 dark:text-green-400 text-xs">Saved ✓</span>
          </div>
          <div>
            <label class="label">Event Name *</label>
            <input v-model="editForm.name" class="input" required maxlength="120" />
          </div>
          <div>
            <label class="label">Tagline</label>
            <input v-model="editForm.tagline" class="input" maxlength="200" />
          </div>
          <div>
            <label class="label">Description</label>
            <textarea v-model="editForm.description" class="input" rows="3" />
          </div>
          <div>
            <label class="label">District / Niknax Event Link</label>
            <input v-model="editForm.district_link" class="input" type="url" placeholder="https://districtapp.tv/…" />
          </div>

          <div>
            <label class="label">Train Graphic</label>
            <ImageUpload
              :current-url="editForm.cover_url"
              @file-selected="onCoverSelected"
              @cleared="editForm.cover_url = null; coverFile = null; coverPct = 0; coverStatus = ''"
            />
            <p v-if="coverStatus" class="text-xs text-tx3 mt-1.5">{{ coverStatus }}</p>
          </div>

          <div>
            <div class="flex items-center justify-between mb-1">
              <label class="label mb-0">Sign-Up Rules &amp; Criteria</label>
              <button
                type="button"
                @click="showRules = !showRules"
                class="text-xs text-niknax-600 dark:text-niknax-400 hover:underline"
              >{{ showRules ? 'Hide' : 'Edit rules' }}</button>
            </div>
            <p class="text-xs text-tx3 mb-2">
              Shown to sellers before they can claim a slot on your train.
            </p>
            <textarea
              v-if="showRules"
              v-model="editForm.rules_md"
              class="input font-mono text-xs"
              rows="14"
            />
          </div>

          <p v-if="detailsError" class="text-red-600 dark:text-red-400 text-sm">{{ detailsError }}</p>
          <div class="flex justify-end">
            <button @click="saveDetails" :disabled="savingDetails" class="btn-primary text-sm py-2">
              {{ savingDetails ? 'Saving…' : 'Save Details' }}
            </button>
          </div>

          <div class="border-t border-bd pt-4 flex items-center justify-between gap-4">
            <div>
              <p class="text-sm font-medium text-tx1">Lock train chat</p>
              <p class="text-xs text-tx3 mt-0.5">
                Freezes posting on your train's chat. Existing messages stay visible.
                You can delete individual messages from the chat panel on your public page.
              </p>
            </div>
            <button
              type="button"
              @click="toggleChatLocked"
              :disabled="savingChatLock"
              :aria-pressed="!!train.chat_locked"
              :class="train.chat_locked ? 'bg-red-500 hover:bg-red-400' : 'bg-sur2 hover:bg-bd'"
              class="relative inline-flex items-center shrink-0 w-11 h-6 rounded-full transition-colors disabled:opacity-50"
            >
              <span
                :class="train.chat_locked ? 'translate-x-6' : 'translate-x-1'"
                class="inline-block w-4 h-4 bg-white rounded-full shadow transition-transform duration-200"
              />
            </button>
          </div>
        </section>

        <!-- Days & slots -->
        <section class="space-y-6 mb-8">
          <div class="flex items-center justify-between">
            <h2 class="text-base font-semibold text-tx1">Schedule</h2>
            <button @click="showAddDay = !showAddDay" class="btn-secondary text-sm py-1.5">+ Add Day</button>
          </div>

          <!-- Add day form -->
          <div v-if="showAddDay" class="card border-2 border-niknax-200 dark:border-niknax-700 space-y-4">
            <h3 class="text-sm font-semibold text-tx2">New Day</h3>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="label">Date *</label>
                <input v-model="newDay.day_date" type="date" class="input" required />
              </div>
              <div>
                <label class="label">Label (optional)</label>
                <input v-model="newDay.day_label" class="input" placeholder="Day 2" />
              </div>
            </div>
            <div class="grid grid-cols-3 gap-4">
              <div>
                <label class="label">Start Time (ET)</label>
                <input v-model="newDay.start_time" type="time" class="input" step="60" />
              </div>
              <div>
                <label class="label">Slot Duration (min)</label>
                <input v-model.number="newDay.slot_duration" type="number" min="5" max="120" class="input" />
              </div>
              <div>
                <label class="label">Slot Count</label>
                <input v-model.number="newDay.slot_count" type="number" min="1" max="100" class="input" />
              </div>
            </div>

            <div class="flex flex-wrap items-end gap-4">
              <label class="flex items-center gap-2 text-sm text-tx2 cursor-pointer select-none">
                <input v-model="newDay.include_kickoff" type="checkbox" class="accent-niknax-600 w-4 h-4" />
                Include a Kickoff slot
              </label>
              <div v-if="newDay.include_kickoff" class="w-32">
                <label class="label">Kickoff (min)</label>
                <input v-model.number="newDay.kickoff_duration" type="number" min="5" max="120" class="input py-1.5" />
              </div>
            </div>

            <p v-if="addDayError" class="text-red-600 dark:text-red-400 text-sm">{{ addDayError }}</p>
            <div class="flex gap-2 justify-end">
              <button @click="showAddDay = false" class="btn-secondary text-sm py-1.5">Cancel</button>
              <button @click="addDay" :disabled="addingDay" class="btn-primary text-sm py-1.5">
                {{ addingDay ? 'Adding…' : 'Add Day' }}
              </button>
            </div>
          </div>

          <!-- Day cards -->
          <div v-for="day in days" :key="day.id" class="card">
            <div class="flex items-center justify-between mb-4 gap-3 flex-wrap">
              <div v-if="editingDayId === day.id" class="flex items-end gap-2 flex-wrap">
                <div>
                  <label class="label">Date</label>
                  <input v-model="dayEdit.day_date" type="date" class="input py-1.5 text-sm" />
                </div>
                <div>
                  <label class="label">Label</label>
                  <input v-model="dayEdit.day_label" class="input py-1.5 text-sm" placeholder="Day 1" maxlength="60" />
                </div>
                <button @click="saveDayEdit(day)" :disabled="savingDayId === day.id" class="btn-primary text-xs py-1.5 px-3">
                  {{ savingDayId === day.id ? '…' : 'Save' }}
                </button>
                <button @click="editingDayId = null" class="text-tx3 hover:text-tx1 text-xs">Cancel</button>
              </div>
              <div v-else>
                <span class="font-semibold text-tx1">{{ formatDate(day.day_date) }}</span>
                <span v-if="day.day_label" class="text-tx3 text-sm ml-2">{{ day.day_label }}</span>
                <button
                  @click="startDayEdit(day)"
                  class="ml-2 text-xs text-niknax-600 hover:text-niknax-500 dark:text-niknax-400"
                >Edit date</button>
              </div>
              <div class="flex items-center gap-3">
                <button
                  @click="toggleScheduleForm(day)"
                  class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-xs"
                >{{ openScheduleDayId === day.id ? 'Close' : 'Adjust schedule' }}</button>
                <button
                  @click="confirmRemoveDay(day)"
                  class="text-red-600 hover:text-red-500 dark:text-red-400 dark:hover:text-red-300 text-xs"
                >Remove day</button>
              </div>
            </div>

            <!-- Schedule regeneration -->
            <div
              v-if="openScheduleDayId === day.id && scheduleForms[day.id]"
              class="bg-sur2 rounded-lg p-4 mb-4 space-y-4"
            >
              <p class="text-sm font-medium text-tx2">Adjust this day's schedule</p>
              <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div>
                  <label class="label">Start Time (ET)</label>
                  <input v-model="scheduleForms[day.id].start_time" type="time" step="60" class="input py-1.5" />
                </div>
                <div>
                  <label class="label">Slot Duration (min)</label>
                  <input v-model.number="scheduleForms[day.id].slot_duration" type="number" min="5" max="120" class="input py-1.5" />
                </div>
                <div>
                  <label class="label">Number of Slots</label>
                  <input v-model.number="scheduleForms[day.id].slot_count" type="number" min="1" max="100" class="input py-1.5" />
                </div>
              </div>

              <div class="flex flex-wrap items-end gap-4">
                <label class="flex items-center gap-2 text-sm text-tx2 cursor-pointer select-none">
                  <input v-model="scheduleForms[day.id].include_kickoff" type="checkbox" class="accent-niknax-600 w-4 h-4" />
                  Include a Kickoff slot
                </label>
                <div v-if="scheduleForms[day.id].include_kickoff" class="w-32">
                  <label class="label">Kickoff (min)</label>
                  <input v-model.number="scheduleForms[day.id].kickoff_duration" type="number" min="5" max="120" class="input py-1.5" />
                </div>
              </div>

              <p class="text-xs text-tx3">
                Sellers keep their position — the first seller slot stays first. Reducing the
                slot count removes rows from the end, along with anyone signed up in them.
              </p>

              <p v-if="scheduleError" class="text-red-600 dark:text-red-400 text-sm">{{ scheduleError }}</p>

              <div class="flex gap-2 justify-end">
                <button @click="openScheduleDayId = null" class="btn-secondary text-sm py-1.5">Cancel</button>
                <button
                  @click="applySchedule(day)"
                  :disabled="savingSchedule"
                  class="btn-primary text-sm py-1.5"
                >{{ savingSchedule ? 'Applying…' : 'Apply Changes' }}</button>
              </div>
            </div>

            <!-- Slot table -->
            <div class="overflow-x-auto -mx-2">
              <table class="w-full text-sm min-w-[500px]">
                <thead>
                  <tr class="border-b border-bd text-left text-xs text-tx3 uppercase tracking-wide">
                    <th class="px-2 py-1.5">#</th>
                    <th class="px-2 py-1.5">Time (ET)</th>
                    <th class="px-2 py-1.5">Duration</th>
                    <th class="px-2 py-1.5">Label</th>
                    <th class="px-2 py-1.5">Seller</th>
                    <th class="px-2 py-1.5 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="(slot, idx) in slotsByDay[day.id] || []"
                    :key="slot.id"
                    class="border-b border-bd/40 last:border-0"
                    :class="slot.id === editingSlotId ? 'bg-sur2' : ''"
                  >
                    <td class="px-2 py-2 text-tx3 font-mono text-xs">{{ slot.slot_order === 0 ? '★' : slot.slot_order }}</td>

                    <!-- View mode -->
                    <template v-if="editingSlotId !== slot.id">
                      <td class="px-2 py-2 font-mono text-xs">{{ formatSlotTime(slot.start_time) }}</td>
                      <td class="px-2 py-2 text-tx3 text-xs">{{ slot.duration_min }}m</td>
                      <td class="px-2 py-2 text-tx3 text-xs">{{ slot.label || '—' }}</td>
                      <td class="px-2 py-2">
                        <span v-if="slot.username" class="flex items-center gap-1.5">
                          <span class="text-tx1 text-xs font-medium">@{{ slot.username }}</span>
                          <button
                            @click="confirmClearSeller(slot)"
                            :disabled="clearingSlotId === slot.id"
                            class="text-tx3 hover:text-red-600 dark:hover:text-red-400 text-xs disabled:opacity-50"
                            :title="`Release this slot — removes @${slot.username} from the train`"
                          >{{ clearingSlotId === slot.id ? '…' : '✕' }}</button>
                        </span>
                        <span v-else class="text-tx3 text-xs italic">— open —</span>
                      </td>
                      <td class="px-2 py-2 text-right">
                        <span class="flex gap-2 justify-end">
                          <button @click="startEditSlot(slot)" class="text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-xs">Edit</button>
                          <button
                            @click="confirmDeleteSlot(slot, day)"
                            :disabled="deletingSlotId === slot.id"
                            class="text-red-600 hover:text-red-500 dark:text-red-400 dark:hover:text-red-300 text-xs disabled:opacity-50"
                          >{{ deletingSlotId === slot.id ? '…' : 'Delete' }}</button>
                        </span>
                      </td>
                    </template>

                    <!-- Edit mode -->
                    <template v-else>
                      <td class="px-2 py-2">
                        <input v-model="slotEdit.start_time" type="time" class="input text-xs py-1" step="60" />
                      </td>
                      <td class="px-2 py-2">
                        <input v-model.number="slotEdit.duration_min" type="number" min="5" max="120" class="input text-xs py-1 w-16" />
                      </td>
                      <td class="px-2 py-2">
                        <input v-model="slotEdit.label" class="input text-xs py-1" placeholder="Label" maxlength="60" />
                      </td>
                      <td class="px-2 py-2 text-tx3 text-xs italic">{{ slot.username ? `@${slot.username}` : '— open —' }}</td>
                      <td class="px-2 py-2 text-right">
                        <span class="flex gap-1 justify-end">
                          <button @click="saveSlotEdit(slot, day)" :disabled="savingSlotId === slot.id" class="text-green-700 dark:text-green-400 text-xs font-medium">{{ savingSlotId === slot.id ? '…' : 'Save' }}</button>
                          <button @click="editingSlotId = null" class="text-tx3 text-xs">✕</button>
                        </span>
                      </td>
                    </template>
                  </tr>
                </tbody>
              </table>
            </div>

            <!-- Add slot -->
            <div class="mt-4 pt-4 border-t border-bd">
              <details class="text-sm">
                <summary class="cursor-pointer text-niknax-600 hover:text-niknax-500 dark:text-niknax-400 dark:hover:text-niknax-300 text-xs font-medium list-none">+ Add slot to this day</summary>
                <div class="mt-3 grid grid-cols-3 gap-3 items-end">
                  <div>
                    <label class="label text-xs">Start Time (ET)</label>
                    <input v-model="newSlots[day.id].start_time" type="time" class="input text-sm py-1.5" step="60" />
                  </div>
                  <div>
                    <label class="label text-xs">Duration (min)</label>
                    <input v-model.number="newSlots[day.id].duration_min" type="number" min="5" max="120" class="input text-sm py-1.5" />
                  </div>
                  <div>
                    <label class="label text-xs">Label (optional)</label>
                    <input v-model="newSlots[day.id].label" class="input text-sm py-1.5" placeholder="e.g. Boost" maxlength="60" />
                  </div>
                  <div class="col-span-3 flex justify-end gap-2">
                    <button
                      @click="addSlot(day)"
                      :disabled="addingSlotDayId === day.id"
                      class="btn-primary text-xs py-1.5"
                    >{{ addingSlotDayId === day.id ? 'Adding…' : 'Add Slot' }}</button>
                  </div>
                </div>
              </details>
            </div>
          </div>

          <div v-if="days.length === 0" class="text-tx3 text-sm italic">No days scheduled yet.</div>
        </section>

        <!-- Co-conductors -->
        <section class="card space-y-4 mb-8">
          <div>
            <h2 class="text-base font-semibold text-tx1">Conductors</h2>
            <p class="text-xs text-tx3 mt-1">
              Anyone listed here can manage this train. They sign in with their own email
              and get their own access code — no sharing passwords.
            </p>
          </div>

          <ul class="space-y-2">
            <li
              v-for="c in conductors"
              :key="c.email"
              class="flex items-center justify-between gap-3 bg-sur2 rounded-lg px-3 py-2"
            >
              <div class="min-w-0">
                <p class="text-sm text-tx1 truncate">{{ c.email }}</p>
                <p class="text-xs text-tx3">
                  <span v-if="c.username">@{{ c.username }}</span>
                  <span v-if="c.is_primary"><span v-if="c.username"> · </span>primary</span>
                </p>
              </div>
              <button
                v-if="!c.is_primary"
                @click="removeConductor(c)"
                :disabled="removingEmail === c.email"
                class="text-red-600 hover:text-red-500 dark:text-red-400 dark:hover:text-red-300 text-xs shrink-0 disabled:opacity-50"
              >{{ removingEmail === c.email ? '…' : 'Remove' }}</button>
            </li>
          </ul>

          <form @submit.prevent="addConductor" class="flex flex-col sm:flex-row gap-2">
            <input
              v-model="newConductorEmail"
              type="email"
              class="input flex-1"
              placeholder="co-conductor@example.com"
              required
            />
            <button type="submit" :disabled="addingConductor" class="btn-secondary text-sm py-2 shrink-0">
              {{ addingConductor ? 'Adding…' : 'Add conductor' }}
            </button>
          </form>

          <p v-if="conductorError" class="text-red-600 dark:text-red-400 text-sm">{{ conductorError }}</p>
        </section>

        <!-- Change history -->
        <section class="card mb-8">
          <button
            @click="toggleHistory"
            class="flex items-center justify-between w-full text-left"
            :aria-expanded="showHistory"
          >
            <span class="text-base font-semibold text-tx1">
              Change History
              <span v-if="history.length" class="text-tx3 font-normal text-sm">({{ history.length }})</span>
            </span>
            <span class="text-tx3 text-lg">{{ showHistory ? '▲' : '▼' }}</span>
          </button>

          <div v-if="showHistory" class="mt-4">
            <p v-if="loadingHistory" class="text-tx3 text-sm py-4 text-center">Loading…</p>

            <p v-else-if="history.length === 0" class="text-tx3 text-sm py-4">
              No changes recorded yet.
            </p>

            <ol v-else class="space-y-2 max-h-96 overflow-y-auto">
              <li
                v-for="h in history"
                :key="h.id"
                class="border-l-2 pl-3 py-1.5"
                :class="{
                  'border-green-500': h.action === 'INSERT',
                  'border-amber-500': h.action === 'UPDATE',
                  'border-red-500':   h.action === 'DELETE',
                }"
              >
                <p class="text-sm text-tx1">{{ h.summary }}</p>
                <p class="text-xs text-tx3">
                  {{ h.actor ? '@' + h.actor : 'someone' }} · {{ formatHistoryTime(h.created_at) }}
                </p>
              </li>
            </ol>
          </div>
        </section>

        <!-- Error -->
        <p v-if="actionError" class="text-red-600 dark:text-red-400 text-sm mb-4" role="alert">{{ actionError }}</p>
      </template>
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink, useRoute, useRouter } from 'vue-router'
import PublicNav from '../../components/PublicNav.vue'
import ImageUpload from '../../components/ImageUpload.vue'
import { supabase, uploadWithProgress } from '../../lib/supabase.js'
import { getConductorSession, setConductorSession, clearConductorSession } from '../../lib/conductorAuth.js'
import { formatDate, parseTime, addMinutes } from '../../lib/timeUtils.js'

const route  = useRoute()
const router = useRouter()

const loading = ref(true)
const train   = ref(null)
const days    = ref([])
const slots   = ref([])

// ── Auth gate ──────────────────────────────────────────────────────────────
// Access is proven by receiving a one-time code at a registered email, not by
// typing a username. Every write RPC takes the resulting session token.
const authToken      = ref('')
const authEmail      = ref('')
const authedUsername = ref(null)   // display only
const isPrimary      = ref(false)
const conductors     = ref([])

const gateCode    = ref('')
const gateLoading = ref(false)
const gateError   = ref('')

/**
 * Keeps the field readable as they type: uppercase, drop anything outside the
 * code alphabet, and re-insert the dash after four characters. Means a code
 * pasted as "abcd efgh" or typed without the dash still works.
 */
function formatCodeInput(value) {
  const cleaned = String(value || '').toUpperCase().replace(/[^2-9A-HJ-NP-Z]/g, '').slice(0, 8)
  return cleaned.length > 4 ? `${cleaned.slice(0, 4)}-${cleaned.slice(4)}` : cleaned
}

async function submitCode() {
  gateError.value   = ''
  gateLoading.value = true

  const { data, error } = await supabase.rpc('redeem_conductor_code', {
    p_train_id: train.value.id,
    p_code:     gateCode.value.trim(),
  })

  if (error) {
    gateError.value = error.message || 'That code did not work.'
  } else {
    setConductorSession(train.value.id, {
      token:     data.token,
      email:     data.email,
      username:  data.username,
      expiresAt: data.expires_at,
    })
    applySession({ token: data.token, email: data.email, username: data.username })
    await loadSessionInfo()
  }
  gateLoading.value = false
}

function applySession(session) {
  authToken.value      = session.token
  authEmail.value      = session.email || ''
  authedUsername.value = session.username || session.email || 'conductor'
}

async function loadSessionInfo() {
  if (!authToken.value) return
  const { data } = await supabase.rpc('conductor_session_info', {
    p_train_id: train.value.id,
    p_token:    authToken.value,
  })
  if (data?.valid) {
    isPrimary.value  = !!data.is_primary
    conductors.value = data.conductors || []
    if (data.username) authedUsername.value = data.username
    if (data.email)    authEmail.value      = data.email
  } else {
    signOutConductor()
  }
}

function signOutConductor() {
  clearConductorSession(train.value?.id)
  authToken.value = ''
  authEmail.value = ''
  authedUsername.value = null
  conductors.value = []
  gateCode.value = ''
  gateError.value = ''
}

/**
 * Server-side session expiry surfaces as an error with detail
 * 'conductor_auth'. Drop the local session so the gate reappears rather than
 * leaving the conductor clicking buttons that silently fail.
 */
function handleRpcError(error, fallback) {
  if (error?.details === 'conductor_auth') {
    signOutConductor()
    return 'Your access has expired. Request a new code to continue.'
  }
  return error?.message || fallback
}

// ── Schedule regeneration ─────────────────────────────────────────────────
const openScheduleDayId = ref(null)
const scheduleForms     = ref({})
const savingSchedule    = ref(false)
const scheduleError     = ref('')

function isKickoff(slot) {
  return String(slot?.label || '').trim().toLowerCase() === 'kickoff'
}

function toggleScheduleForm(day) {
  scheduleError.value = ''
  if (openScheduleDayId.value === day.id) {
    openScheduleDayId.value = null
    return
  }

  // Seed from what's actually on the day, so the form reflects reality.
  const daySlots = (slotsByDay.value[day.id] || [])
  const kickoff  = daySlots.find(isKickoff)
  const sellers  = daySlots.filter(s => !isKickoff(s))

  scheduleForms.value[day.id] = {
    start_time:       String(kickoff?.start_time || sellers[0]?.start_time || '10:30').slice(0, 5),
    slot_duration:    sellers[0]?.duration_min || 30,
    slot_count:       Math.max(1, sellers.length || 1),
    include_kickoff:  !!kickoff,
    kickoff_duration: kickoff?.duration_min || 10,
  }
  openScheduleDayId.value = day.id
}

async function applySchedule(day) {
  const form = scheduleForms.value[day.id]
  scheduleError.value = ''

  const daySlots   = (slotsByDay.value[day.id] || [])
  const sellers    = daySlots.filter(s => !isKickoff(s))
  const losing     = sellers.slice(form.slot_count).filter(s => s.username)
  const kickoff    = daySlots.find(isKickoff)
  const losingKick = !form.include_kickoff && kickoff?.username ? [kickoff] : []
  const atRisk     = [...losingKick, ...losing]

  if (atRisk.length) {
    const names = atRisk.map(s => `@${s.username}`).join(', ')
    if (!confirm(`This removes ${names} from the train.\n\nContinue?`)) return
  }

  savingSchedule.value = true
  const { error } = await supabase.rpc('regenerate_member_train_schedule', {
    p_train_id:         train.value.id,
    p_token:            authToken.value,
    p_day_id:           day.id,
    p_start_time:       form.start_time,
    p_slot_duration:    form.slot_duration,
    p_slot_count:       form.slot_count,
    p_include_kickoff:  form.include_kickoff,
    p_kickoff_duration: form.kickoff_duration,
  })

  if (error) {
    scheduleError.value = handleRpcError(error, 'Could not update the schedule.')
  } else {
    await reloadSlots()
    openScheduleDayId.value = null
  }
  savingSchedule.value = false
}

// ── Release a slot ────────────────────────────────────────────────────────
const clearingSlotId = ref(null)

async function confirmClearSeller(slot) {
  if (!confirm(`Remove @${slot.username} from this slot?\n\nThe slot stays and becomes open for someone else.`)) return

  clearingSlotId.value = slot.id
  const { error } = await supabase.rpc('clear_member_train_slot_seller', {
    p_train_id: train.value.id,
    p_token:    authToken.value,
    p_slot_id:  slot.id,
  })

  if (error) {
    actionError.value = handleRpcError(error, 'Could not release that slot.')
  } else {
    const local = slots.value.find(s => s.id === slot.id)
    if (local) { local.username = null; local.seller_link = null }
  }
  clearingSlotId.value = null
}

// ── Train status ──────────────────────────────────────────────────────────
const savingStatus = ref(false)
const statusError  = ref('')

async function setStatus(status) {
  if (savingStatus.value) return
  // Already in that state — nothing to do.
  if ((status === 'boarding' && train.value.published) ||
      (status === 'upcoming' && train.value.is_upcoming && !train.value.published)) return

  statusError.value  = ''
  savingStatus.value = true

  const { data, error } = await supabase.rpc('set_member_train_status', {
    p_train_id: train.value.id,
    p_token:    authToken.value,
    p_status:   status,
  })

  if (error) {
    statusError.value = handleRpcError(error, 'Could not change the status.')
  } else {
    Object.assign(train.value, data)
  }
  savingStatus.value = false
}

// ── Day date / label ──────────────────────────────────────────────────────
const editingDayId = ref(null)
const savingDayId  = ref(null)
const dayEdit      = ref({ day_date: '', day_label: '' })

function startDayEdit(day) {
  editingDayId.value = day.id
  dayEdit.value = { day_date: day.day_date, day_label: day.day_label || '' }
}

async function saveDayEdit(day) {
  savingDayId.value = day.id
  actionError.value = ''

  const { data, error } = await supabase.rpc('update_member_train_day', {
    p_train_id:  train.value.id,
    p_token:     authToken.value,
    p_day_id:    day.id,
    p_day_date:  dayEdit.value.day_date || null,
    p_day_label: dayEdit.value.day_label ?? '',
  })

  if (error) {
    actionError.value = handleRpcError(error, 'Could not update that day.')
  } else {
    Object.assign(day, data)
    editingDayId.value = null
  }
  savingDayId.value = null
}

// ── Change history ────────────────────────────────────────────────────────
const history        = ref([])
const showHistory    = ref(false)
const loadingHistory = ref(false)

async function toggleHistory() {
  showHistory.value = !showHistory.value
  if (showHistory.value && history.value.length === 0) await loadHistory()
}

async function loadHistory() {
  loadingHistory.value = true
  const { data, error } = await supabase.rpc('conductor_train_history', {
    p_train_id: train.value.id,
    p_token:    authToken.value,
    p_limit:    200,
  })
  if (error) actionError.value = handleRpcError(error, 'Could not load history.')
  history.value = data || []
  loadingHistory.value = false
}

function formatHistoryTime(iso) {
  return new Date(iso).toLocaleString(undefined, {
    month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  })
}

// ── Co-conductors ─────────────────────────────────────────────────────────
const newConductorEmail = ref('')
const addingConductor   = ref(false)
const removingEmail     = ref(null)
const conductorError    = ref('')

async function addConductor() {
  conductorError.value = ''
  addingConductor.value = true

  const { error } = await supabase.rpc('add_train_conductor', {
    p_train_id: train.value.id,
    p_token:    authToken.value,
    p_email:    newConductorEmail.value.trim(),
    p_username: null,
  })

  if (error) {
    conductorError.value = handleRpcError(error, 'Could not add that conductor.')
  } else {
    newConductorEmail.value = ''
    await loadSessionInfo()
  }
  addingConductor.value = false
}

async function removeConductor(c) {
  if (!confirm(`Remove ${c.email} as a conductor?\n\nThey'll lose access immediately.`)) return

  conductorError.value = ''
  removingEmail.value  = c.email

  const { error } = await supabase.rpc('remove_train_conductor', {
    p_train_id: train.value.id,
    p_token:    authToken.value,
    p_email:    c.email,
  })

  if (error) {
    conductorError.value = handleRpcError(error, 'Could not remove that conductor.')
  } else {
    await loadSessionInfo()
  }
  removingEmail.value = null
}

// ── Data loading ───────────────────────────────────────────────────────────
const slotsByDay = computed(() => {
  const map = {}
  for (const s of slots.value) {
    if (!map[s.train_day_id]) map[s.train_day_id] = []
    map[s.train_day_id].push(s)
  }
  for (const k in map) {
    map[k].sort((a, b) => (a.slot_order - b.slot_order) || a.start_time.localeCompare(b.start_time))
  }
  return map
})

async function load() {
  loading.value = true
  const id = route.params.id

  const { data: t } = await supabase.from('trains').select('*').eq('id', id).single()
  if (!t || !t.is_member_train) { loading.value = false; return }
  train.value = t

  // Restore a stored session. The server re-validates the token, so a revoked
  // or expired one is rejected even though it's still in localStorage.
  const session = getConductorSession(id)
  if (session?.token) {
    applySession(session)
    await loadSessionInfo()
  }

  const { data: d } = await supabase.from('train_days').select('*').eq('train_id', id).order('day_order')
  days.value = d || []

  if (days.value.length) {
    const { data: s } = await supabase
      .from('slots').select('*')
      .in('train_day_id', days.value.map(d => d.id))
      .order('slot_order')
    slots.value = s || []
  }

  // Seed per-day new slot forms
  for (const day of days.value) {
    if (!newSlots.value[day.id]) {
      newSlots.value[day.id] = defaultNewSlot(day.id)
    }
  }

  // Pre-fill edit form
  editForm.value = {
    name:          t.name,
    tagline:       t.tagline || '',
    description:   t.description || '',
    district_link: t.district_link || '',
    cover_url:     t.cover_url || '',
    rules_md:      t.rules_md || '',
  }

  loading.value = false
}

onMounted(load)

// ── Train details editing ──────────────────────────────────────────────────
const editForm     = ref({ name: '', tagline: '', description: '', district_link: '' })
const savingDetails = ref(false)
const detailsError  = ref('')
const detailsSaved  = ref(false)

// ── Cover image ───────────────────────────────────────────────────────────
const coverFile   = ref(null)
const coverPct    = ref(0)
const coverStatus = ref('')
const showRules   = ref(false)

function onCoverSelected(file) {
  coverFile.value = file
  coverStatus.value = file ? 'Graphic will upload when you save.' : ''
}

async function uploadCoverIfNeeded() {
  if (!coverFile.value) return editForm.value.cover_url || null

  const ext = (coverFile.value.name.split('.').pop() || 'jpg').toLowerCase()
  coverStatus.value = 'Uploading graphic…'
  const url = await uploadWithProgress(
    'train-graphics',
    `${train.value.id}/cover.${ext}`,
    coverFile.value,
    (pct) => { coverPct.value = pct },
  )
  coverStatus.value = 'Graphic uploaded ✓'
  coverFile.value = null
  return url
}

async function saveDetails() {
  detailsError.value = ''
  savingDetails.value = true

  let coverUrl = editForm.value.cover_url || null
  try {
    coverUrl = await uploadCoverIfNeeded()
  } catch (e) {
    detailsError.value = e?.message || 'Could not upload the graphic.'
    coverStatus.value = ''
    savingDetails.value = false
    return
  }

  const { data, error } = await supabase.rpc('update_member_train', {
    p_train_id:      train.value.id,
    p_conductor:     authToken.value,
    p_name:          editForm.value.name.trim(),
    p_tagline:       editForm.value.tagline.trim() || null,
    p_description:   editForm.value.description.trim() || null,
    p_district_link: editForm.value.district_link.trim() || null,
    p_rules_md:      editForm.value.rules_md?.trim() || null,
    p_cover_url:     coverUrl,
  })
  if (error) {
    detailsError.value = error.message
  } else {
    Object.assign(train.value, data)
    detailsSaved.value = true
    setTimeout(() => detailsSaved.value = false, 2000)
  }
  savingDetails.value = false
}

const savingChatLock = ref(false)

async function toggleChatLocked() {
  savingChatLock.value = true
  const val = !train.value.chat_locked
  const { error } = await supabase.rpc('set_member_train_chat_locked', {
    p_train_id:  train.value.id,
    p_conductor: authToken.value,
    p_locked:    val,
  })
  if (error) {
    detailsError.value = error.message
  } else {
    train.value.chat_locked = val
  }
  savingChatLock.value = false
}

// ── Delete train ───────────────────────────────────────────────────────────
const deleting     = ref(false)
const actionError  = ref('')

async function confirmDeleteTrain() {
  if (!confirm(`Delete "${train.value.name}"? This cannot be undone.`)) return
  deleting.value = true
  const { error } = await supabase.rpc('delete_member_train', {
    p_train_id:  train.value.id,
    p_conductor: authToken.value,
  })
  if (error) {
    actionError.value = error.message
    deleting.value = false
  } else {
    router.push('/')
  }
}

// ── Add / remove day ───────────────────────────────────────────────────────
const showAddDay  = ref(false)
const addingDay   = ref(false)
const addDayError = ref('')
const newDay      = ref({ day_date: '', day_label: '', start_time: '10:30', slot_duration: 30, slot_count: 24, include_kickoff: true, kickoff_duration: 10 })
const newSlots    = ref({})

async function addDay() {
  addDayError.value = ''
  if (!newDay.value.day_date) { addDayError.value = 'Date is required.'; return }
  addingDay.value = true

  const { data, error } = await supabase.rpc('add_member_train_day', {
    p_train_id:      train.value.id,
    p_conductor:     authToken.value,
    p_day_date:      newDay.value.day_date,
    p_day_label:     newDay.value.day_label || null,
    p_start_time:    newDay.value.start_time,
    p_slot_duration:    newDay.value.slot_duration,
    p_slot_count:       newDay.value.slot_count,
    p_include_kickoff:  newDay.value.include_kickoff,
    p_kickoff_duration: newDay.value.kickoff_duration,
  })

  if (error) {
    addDayError.value = error.message
  } else {
    const result = typeof data === 'string' ? JSON.parse(data) : data
    days.value.push(result.day)
    slots.value.push(...(result.slots || []))
    newSlots.value[result.day.id] = defaultNewSlot(result.day.id)
    newDay.value = { day_date: '', day_label: '', start_time: '10:30', slot_duration: 30, slot_count: 24, include_kickoff: true, kickoff_duration: 10 }
    showAddDay.value = false
  }
  addingDay.value = false
}

async function confirmRemoveDay(day) {
  const daySlots = slotsByDay.value[day.id] || []
  if (!confirm(`Remove ${formatDate(day.day_date)} and all ${daySlots.length} of its slots?`)) return

  const { error } = await supabase.rpc('remove_member_train_day', {
    p_train_id:  train.value.id,
    p_conductor: authToken.value,
    p_day_id:    day.id,
  })
  if (error) {
    actionError.value = error.message
  } else {
    days.value = days.value.filter(d => d.id !== day.id)
    slots.value = slots.value.filter(s => s.train_day_id !== day.id)
    delete newSlots.value[day.id]
  }
}

// ── Slot editing ───────────────────────────────────────────────────────────
const editingSlotId = ref(null)
const savingSlotId  = ref(null)
const slotEdit      = ref({ start_time: '', duration_min: 30, label: '' })

function startEditSlot(slot) {
  editingSlotId.value = slot.id
  slotEdit.value = {
    start_time:   slot.start_time.slice(0, 5),
    duration_min: slot.duration_min,
    label:        slot.label || '',
  }
}

async function saveSlotEdit(slot, day) {
  savingSlotId.value = slot.id
  const { data, error } = await supabase.rpc('edit_member_train_slot', {
    p_train_id:   train.value.id,
    p_conductor:  authToken.value,
    p_slot_id:    slot.id,
    p_start_time: slotEdit.value.start_time || null,
    p_duration:   slotEdit.value.duration_min,
    p_label:      slotEdit.value.label || null,
  })
  if (error) {
    actionError.value = error.message
  } else {
    Object.assign(slot, data)
    editingSlotId.value = null
  }
  savingSlotId.value = null
}

// ── Slot deletion ──────────────────────────────────────────────────────────
const deletingSlotId = ref(null)

async function confirmDeleteSlot(slot, day) {
  const daySlots = slotsByDay.value[day.id] || []
  const idx = daySlots.findIndex(s => s.id === slot.id)
  const later = daySlots.slice(idx + 1).length
  const label = slot.username ? `@${slot.username}'s slot` : 'this open slot'
  const msg = later
    ? `Delete ${label}? The ${later} slot${later === 1 ? '' : 's'} after it will shift ${slot.duration_min}m earlier.`
    : `Delete ${label}?`
  if (!confirm(msg)) return

  deletingSlotId.value = slot.id
  const { error } = await supabase.rpc('delete_member_train_slot', {
    p_train_id:  train.value.id,
    p_conductor: authToken.value,
    p_slot_id:   slot.id,
  })
  if (error) {
    actionError.value = error.message
  } else {
    // Apply the time shift locally (mirrors the DB logic)
    const idx2 = daySlots.indexOf(slot)
    for (let i = idx2 + 1; i < daySlots.length; i++) {
      const s = daySlots[i]
      const { hours, minutes } = parseTime(s.start_time)
      const totalMin = hours * 60 + minutes - slot.duration_min
      const wrapped = ((totalMin % 1440) + 1440) % 1440
      s.start_time = `${String(Math.floor(wrapped / 60)).padStart(2, '0')}:${String(wrapped % 60).padStart(2, '0')}`
      s.slot_order--
    }
    slots.value = slots.value.filter(s => s.id !== slot.id)
  }
  deletingSlotId.value = null
}

// ── Add slot ───────────────────────────────────────────────────────────────
const addingSlotDayId = ref(null)

/**
 * Default a new slot to the moment the day's last slot ends. The old hardcoded
 * 10:30 was wrong for any evening train — on a 4:30 PM start it read as the
 * next morning and sorted to the bottom of the day.
 */
function defaultNewSlot(dayId) {
  const daySlots = slots.value
    .filter(s => s.train_day_id === dayId)
    .sort((a, b) => a.slot_order - b.slot_order)
  const last = daySlots[daySlots.length - 1]
  return {
    start_time:   last ? addMinutes(last.start_time, last.duration_min || 30) : '10:30',
    duration_min: last?.duration_min || 30,
    label:        '',
  }
}

async function addSlot(day) {
  addingSlotDayId.value = day.id
  const ns = newSlots.value[day.id]
  const { data, error } = await supabase.rpc('add_member_train_slot', {
    p_train_id:   train.value.id,
    p_conductor:  authToken.value,
    p_day_id:     day.id,
    p_start_time: ns.start_time,
    p_duration:   ns.duration_min,
    p_label:      ns.label || null,
  })
  if (error) {
    actionError.value = error.message
  } else {
    slots.value.push(data)
    // The RPC renumbers slot_order around the insert — reload so the local
    // list matches the server rather than drifting out of order.
    await reloadSlots()
    newSlots.value[day.id] = defaultNewSlot(day.id)
  }
  addingSlotDayId.value = null
}

async function reloadSlots() {
  const { data } = await supabase
    .from('slots')
    .select('*')
    .in('train_day_id', days.value.map(d => d.id))
    .order('slot_order')
  if (data) slots.value = data
}

// ── Helpers ────────────────────────────────────────────────────────────────
function formatSlotTime(t) {
  if (!t) return '—'
  const { hours, minutes } = parseTime(t)
  const h = ((hours % 12) || 12)
  const ampm = hours < 12 ? 'AM' : 'PM'
  return `${h}:${String(minutes).padStart(2, '0')} ${ampm}`
}
</script>
