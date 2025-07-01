defmodule ReddevsWeb.AlertLive.RegisterConfirm do
  use ReddevsWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="cyberpunk-container min-h-screen bg-gray-900 flex items-center justify-center p-4">
      <div class="cyberpunk-card max-w-2xl w-full bg-gray-800 border-2 border-cyan-500 p-8 md:p-12
                  relative overflow-hidden shadow-[0_0_40px_rgba(34,211,238,0.3)]">
        <div class="absolute top-0 left-0 right-0 h-1 bg-cyan-500 animate-scanline z-20"></div>

        <div class="absolute top-3 left-3 w-4 h-4 border-t-2 border-l-2 border-cyan-400 z-10"></div>
        <div class="absolute top-3 right-3 w-4 h-4 border-t-2 border-r-2 border-cyan-400 z-10"></div>
        <div class="absolute bottom-3 left-3 w-4 h-4 border-b-2 border-l-2 border-cyan-400 z-10">
        </div>
        <div class="absolute bottom-3 right-3 w-4 h-4 border-b-2 border-r-2 border-cyan-400 z-10">
        </div>

        <div class="relative z-30">
          <h1 class="text-3xl md:text-4xl font-bold text-cyan-300 mb-6 flex items-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-8 w-8 mr-3 text-cyan-400"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
              />
            </svg>
            АКТИВАЦИЯ АККАУНТА
          </h1>

          <div class="cyberpunk-message bg-gray-900 border border-cyan-700 p-6 mb-8">
            <div class="flex items-start">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 mr-3 text-cyan-400 flex-shrink-0 mt-1"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                />
              </svg>
              <div>
                <p class="text-cyan-100 text-lg mb-3">
                  Ваш аккаунт успешно зарегистрирован в системе <span class="text-cyan-300 font-mono">REDDEVS</span>!
                </p>
                <p class="text-cyan-100">
                  Для завершения регистрации необходимо подтвердить ваш email адрес.
                </p>
              </div>
            </div>
          </div>

          <div class="cyberpunk-instructions bg-gray-900 border border-purple-600 p-6 mb-8">
            <h2 class="text-xl font-bold text-purple-400 mb-4 flex items-center">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 mr-2"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                />
              </svg>
              ИНСТРУКЦИИ ПО ПОДТВЕРЖДЕНИЮ:
            </h2>

            <ol class="space-y-3 text-cyan-100 pl-6 list-decimal">
              <li>
                Проверьте вашу электронную почту:
                <span class="font-mono text-cyan-300">{@email}</span>
              </li>
              <li>
                Найдите письмо от <span class="font-mono text-cyan-300">REDDEVS</span>
                с темой "Подтверждение регистрации"
              </li>
              <li>Откройте письмо и нажмите на кнопку "Подтвердить аккаунт"</li>
              <li>Если письма нет во входящих, проверьте папку "Спам"</li>
            </ol>
          </div>

          <div class="cyberpunk-actions flex flex-col sm:flex-row justify-between items-start sm:items-center gap-6">
            <div class="text-cyan-200">
              <p>Не получили письмо?</p>
              <p class="text-sm text-cyan-400 mt-1">
                Проверьте спам или запросите повторную отправку
              </p>
            </div>

            <button class="cyberpunk-btn bg-purple-900 text-cyan-300 border-2 border-cyan-400 px-6 py-3
                          font-bold tracking-wider hover:bg-purple-800 hover:text-cyan-200
                          hover:shadow-[0_0_15px_rgba(139,92,246,0.5)] transition-all duration-200
                          relative overflow-hidden w-full sm:w-auto">
              <span class="relative z-10">Отправить письмо повторно</span>
              <span class="absolute inset-0 bg-gradient-to-r from-cyan-400/10 via-purple-500/10 to-cyan-400/10
                          opacity-0 hover:opacity-100 transition-opacity duration-300">
              </span>
            </button>
          </div>
        </div>

        <div class="absolute inset-0 z-0">
          <div class="absolute top-1/4 left-1/4 w-32 h-32 bg-purple-900 rounded-full filter blur-[70px] opacity-30 animate-pulse">
          </div>
          <div class="absolute bottom-1/3 right-1/3 w-40 h-40 bg-cyan-800 rounded-full filter blur-[80px] opacity-20">
          </div>
        </div>
      </div>
    </div>

    <style>
      @keyframes scanline {
        0% { transform: translateY(-100%); }
        100% { transform: translateY(100vh); }
      }

      .animate-scanline {
        animation: scanline 6s linear infinite;
        box-shadow: 0 0 10px rgba(34, 211, 238, 0.7);
      }

      .cyberpunk-card {
        position: relative;
        overflow: hidden;
        box-shadow: 0 0 0 1px rgba(34, 211, 238, 0.3),
                    0 0 30px rgba(34, 211, 238, 0.2),
                    0 0 0 1px rgba(139, 92, 246, 0.1),
                    0 0 10px rgba(139, 92, 246, 0.1);
      }

      .cyberpunk-message {
        position: relative;
        border-left: 3px solid rgb(34, 211, 238);
        box-shadow: inset 0 0 10px rgba(34, 211, 238, 0.2);
      }

      .cyberpunk-instructions {
        position: relative;
        border-left: 3px solid rgb(139, 92, 246);
        box-shadow: inset 0 0 10px rgba(139, 92, 246, 0.2);
      }

      .cyberpunk-btn {
        position: relative;
        overflow: hidden;
        font-family: 'Courier New', monospace;
        text-transform: uppercase;
        letter-spacing: 1px;
      }

      .cyberpunk-btn::before {
        content: '';
        position: absolute;
        top: 0;
        left: -100%;
        width: 100%;
        height: 100%;
        background: linear-gradient(
          90deg,
          transparent,
          rgba(34, 211, 238, 0.4),
          transparent
        );
        transition: 0.5s;
      }

      .cyberpunk-btn:hover::before {
        left: 100%;
      }
    </style>
    """
  end

  @impl true
  def mount(%{"email" => email}, _session, socket) do
    {:ok, assign(socket, :email, email)}
  end
end
