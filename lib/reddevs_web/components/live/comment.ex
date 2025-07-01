defmodule ReddevsWeb.Components.Live.Comments do
  use ReddevsWeb, :live_component

  require Ash.Query

  def update(assigns, socket) do
    resource = assigns[:resource] || raise "Missing :resource assign (:article or :post)"
    comment_resource = assigns[:comment_resource] || raise "Missing :comment_resource assign"
    domain = assigns[:domain] || raise "Missing :domain assign"
    item = assigns[:item] || raise "Missing :item assign (Article or Post)"

    comments = load_comments(item, comment_resource, domain)

    form_params = %{
      "content" => "",
      "#{resource}_id" => item.id,
      "author_id" => assigns.current_user && assigns.current_user.id
    }

    form =
      comment_resource
      |> AshPhoenix.Form.for_create(:create,
        params: form_params,
        domain: domain,
        actor: assigns.current_user
      )
      |> to_form()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:comments, comments)
     |> assign(:comment_changeset, form)
     |> assign(:editing_comment_id, nil)
     |> assign(:replying_to_comment_id, nil)
     |> assign(:edit_changeset, nil)
     |> assign(:reply_changeset, nil)
     |> assign(:resource, resource)
     |> assign(:comment_resource, comment_resource)
     |> assign(:domain, domain)}
  end

  def count_all_comments(comments) do
    top_level_count = length(comments)

    replies_count =
      comments
      |> Enum.map(fn comment ->
        if Map.has_key?(comment, :replies) && is_list(comment.replies),
          do: length(comment.replies),
          else: 0
      end)
      |> Enum.sum()

    top_level_count + replies_count
  end

  def handle_event("validate_comment", %{"form" => params}, socket) do
    form =
      socket.assigns.comment_changeset.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, :comment_changeset, form)}
  end

  def handle_event("add_comment", params, socket) do
    if is_nil(socket.assigns.current_user) do
      {:noreply, put_flash(socket, :error, "Войдите, чтобы оставить комментарий")}
    else
      comment_resource = socket.assigns.comment_resource
      domain = socket.assigns.domain
      resource = socket.assigns.resource

      comment_params =
        case params do
          %{"form" => form_params} ->
            Map.merge(form_params, %{
              "author_id" => socket.assigns.current_user.id,
              "#{resource}_id" => socket.assigns.item.id
            })

          _ ->
            %{
              "content" => "",
              "author_id" => socket.assigns.current_user.id,
              "#{resource}_id" => socket.assigns.item.id
            }
        end

      case AshPhoenix.Form.submit(socket.assigns.comment_changeset.source,
             params: comment_params,
             domain: domain,
             actor: socket.assigns.current_user
           ) do
        {:ok, comment} ->
          {:ok, comment_with_author} =
            Ash.load(comment, :author, actor: socket.assigns.current_user, domain: domain)

          {:ok, item} =
            socket.assigns.item
            |> Ash.Changeset.for_update(:increment_comment_count, %{},
              actor: socket.assigns.current_user,
              domain: domain
            )
            |> Ash.update()

          form =
            comment_resource
            |> AshPhoenix.Form.for_create(:create,
              domain: domain,
              actor: socket.assigns.current_user
            )
            |> to_form()

          {:noreply,
           socket
           |> assign(:item, item)
           |> assign(:comments, [comment_with_author | socket.assigns.comments])
           |> assign(:comment_changeset, form)
           |> put_flash(:info, "Комментарий добавлен")}

        {:error, form} ->
          IO.inspect(form.errors, label: "Form errors")

          {:noreply,
           socket
           |> assign(:comment_changeset, form)
           |> put_flash(:error, "Не удалось добавить комментарий: #{inspect(form.errors)}")}
      end
    end
  end

  def handle_event("delete_comment", %{"id" => comment_id}, socket) do
    comment = find_comment_in_list(socket.assigns.comments, comment_id)
    domain = socket.assigns.domain

    if can_delete_comment?(socket.assigns.current_user, comment) do
      changeset =
        Ash.Changeset.for_update(comment, :hide_comment, %{}, actor: socket.assigns.current_user)

      case Ash.update(changeset) do
        {:ok, _comment} ->
          comments = load_comments(socket.assigns.item, socket.assigns.comment_resource, domain)

          {:noreply,
           socket
           |> assign(:comments, comments)
           |> put_flash(:info, "Комментарий удален")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Не удалось удалить комментарий")}
      end
    else
      {:noreply, put_flash(socket, :error, "У вас нет прав на удаление этого комментария")}
    end
  end

  def handle_event("edit_comment", %{"id" => comment_id}, socket) do
    comment = find_comment_in_list(socket.assigns.comments, comment_id)
    domain = socket.assigns.domain

    if can_edit_comment?(socket.assigns.current_user, comment) do
      edit_form =
        comment
        |> AshPhoenix.Form.for_update(:update_content, domain: domain)
        |> to_form()

      {:noreply,
       socket
       |> assign(:editing_comment_id, comment_id)
       |> assign(:edit_changeset, edit_form)}
    else
      {:noreply, put_flash(socket, :error, "Вы не можете редактировать этот комментарий")}
    end
  end

  def handle_event("validate_edit", %{"form" => params}, socket) do
    form =
      socket.assigns.edit_changeset.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, :edit_changeset, form)}
  end

  def handle_event("save_edit", %{"form" => params}, socket) do
    domain = socket.assigns.domain

    case AshPhoenix.Form.submit(socket.assigns.edit_changeset.source,
           params: params,
           actor: socket.assigns.current_user,
           domain: domain
         ) do
      {:ok, _updated_comment} ->
        comments = load_comments(socket.assigns.item, socket.assigns.comment_resource, domain)

        {:noreply,
         socket
         |> assign(:comments, comments)
         |> assign(:editing_comment_id, nil)
         |> assign(:edit_changeset, nil)
         |> put_flash(:info, "Комментарий обновлен")}

      {:error, form} ->
        {:noreply, assign(socket, :edit_changeset, form)}
    end
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:editing_comment_id, nil)
     |> assign(:edit_changeset, nil)}
  end

  def handle_event("reply_to_comment", %{"id" => comment_id}, socket) do
    comment_resource = socket.assigns.comment_resource
    domain = socket.assigns.domain
    resource = socket.assigns.resource

    if is_nil(socket.assigns.current_user) || is_nil(socket.assigns.item.id) do
      {:noreply,
       put_flash(socket, :error, "You must be logged in and an item must be selected to reply")}
    else
      case comment_resource
           |> Ash.Query.filter(id == ^comment_id)
           |> Ash.read_one(domain: domain) do
        {:ok, comment} when not is_nil(comment) ->
          reply_form =
            comment_resource
            |> AshPhoenix.Form.for_create(:reply,
              params: %{
                "content" => "",
                "#{resource}_id" => socket.assigns.item.id,
                "author_id" => socket.assigns.current_user.id,
                "parent_id" => comment_id
              },
              domain: domain,
              actor: socket.assigns.current_user
            )
            |> to_form()

          {:noreply,
           socket
           |> assign(:replying_to_comment_id, comment_id)
           |> assign(:reply_changeset, reply_form)}

        {:ok, nil} ->
          {:noreply, put_flash(socket, :error, "Parent comment not found")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error loading parent comment")}
      end
    end
  end

  def handle_event("validate_reply", %{"form" => params}, socket) do
    form =
      socket.assigns.reply_changeset.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, :reply_changeset, form)}
  end

  def handle_event("submit_reply", %{"form" => params}, socket) do
    domain = socket.assigns.domain
    resource = socket.assigns.resource

    if is_nil(socket.assigns.item.id) do
      {:noreply, put_flash(socket, :error, "Item ID is missing")}
    else
      reply_params =
        Map.merge(params, %{
          "author_id" => socket.assigns.current_user.id,
          "#{resource}_id" => socket.assigns.item.id,
          "parent_id" => socket.assigns.replying_to_comment_id
        })

      case AshPhoenix.Form.submit(socket.assigns.reply_changeset.source,
             params: reply_params,
             domain: domain
           ) do
        {:ok, reply} ->
          {:ok, _reply_with_author} =
            Ash.load(reply, :author, actor: socket.assigns.current_user, domain: domain)

          {:ok, item} =
            socket.assigns.item
            |> Ash.Changeset.for_update(:increment_comment_count, %{},
              actor: socket.assigns.current_user,
              domain: domain
            )
            |> Ash.update()

          comments = load_comments(item, socket.assigns.comment_resource, domain)

          {:noreply,
           socket
           |> assign(:item, item)
           |> assign(:comments, comments)
           |> assign(:replying_to_comment_id, nil)
           |> assign(:reply_changeset, nil)}

        {:error, form} ->
          {:noreply, assign(socket, :reply_changeset, form)}
      end
    end
  end

  def handle_event("cancel_reply", _, socket) do
    {:noreply,
     socket
     |> assign(:replying_to_comment_id, nil)
     |> assign(:reply_changeset, nil)}
  end

  defp load_comments(item, _comment_resource, domain) do
    case Ash.load(item, :comments, domain: domain) do
      {:ok, loaded_item} ->
        comments = Map.get(loaded_item, :comments, [])

        if Enum.empty?(comments) do
          []
        else
          loaded_comments =
            Ash.load!(comments, [author: [], replies: [author: []]], domain: domain)

          loaded_comments
          |> Enum.filter(fn comment -> is_nil(comment.parent_id) end)
          |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
        end

      {:error, _} ->
        []
    end
  end

  defp find_comment_in_list(comments, comment_id) when is_list(comments) do
    Enum.find_value(comments, fn comment ->
      cond do
        comment.id == comment_id ->
          comment

        Map.has_key?(comment, :replies) && is_list(comment.replies) ->
          Enum.find(comment.replies, &(&1.id == comment_id)) ||
            find_comment_in_list(comment.replies, comment_id)

        true ->
          nil
      end
    end)
  end

  defp find_comment_in_list(_, _), do: nil

  defp user_is_admin?(user) do
    user && Enum.member?(user.badges || [], "Admin")
  end

  defp can_edit_comment?(user, comment) do
    cond do
      is_nil(user) -> false
      is_nil(comment) -> false
      comment.author_id == user.id -> true
      user_is_admin?(user) -> true
      true -> false
    end
  end

  defp can_delete_comment?(user, comment) do
    cond do
      is_nil(user) -> false
      is_nil(comment) -> false
      comment.author_id == user.id -> true
      user_is_admin?(user) -> true
      true -> false
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8">
      <div class="mt-16 cyber-panel p-8 rounded-xl border border-cyan-500/30 bg-gradient-to-b from-gray-900/80 to-gray-800/80 backdrop-blur-sm">
        <h2 class="text-2xl font-bold mb-6 text-cyan-300 neon-text inline-block">
          КОММЕНТАРИИ
        </h2>

        <%= if @current_user do %>
          <.form
            for={@comment_changeset}
            as={:form}
            phx-submit="add_comment"
            phx-change="validate_comment"
            phx-target={@myself}
            class="mb-8 cyber-comment-form"
          >
            <div class="relative">
              <div class="cyber-input-container">
                <.input
                  field={@comment_changeset[:content]}
                  type="textarea"
                  class="w-full bg-gray-800/50 border border-cyan-500/30 rounded-lg py-4 px-4 pl-12 text-cyan-200 focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent h-32 font-mono"
                  placeholder="Введите ваш комментарий..."
                  rows="3"
                />
                <div class="absolute top-4 left-4 text-cyan-500">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M18 13V5a2 2 0 00-2-2H4a2 2 0 00-2 2v8a2 2 0 002 2h3l3 3 3-3h3a2 2 0 002-2zM5 7a1 1 0 011-1h8a1 1 0 110 2H6a1 1 0 01-1-1zm1 3a1 1 0 100 2h6a1 1 0 100-2H6z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </div>
              </div>

              <input type="hidden" name={"form[#{@resource}_id]"} value={@item.id} />
              <input type="hidden" name="form[author_id]" value={@current_user.id} />

              <div class="mt-4 text-right">
                <button
                  type="submit"
                  class="cyber-button px-6 py-3 rounded-lg border border-cyan-500 text-cyan-400 hover:bg-cyan-500/10 transition-all duration-300 group"
                >
                  <span class="group-hover:text-cyan-300 transition-colors">ОТПРАВИТЬ</span>
                  <span class="ml-2 text-xs text-cyan-500 group-hover:text-cyan-300">⏎</span>
                </button>
              </div>
            </div>
          </.form>
        <% else %>
          <div class="cyber-notice p-4 mb-6 rounded-lg border border-cyan-500/30 bg-gray-900/50 backdrop-blur-sm text-center">
            <p class="text-cyan-400">
              <a href={~p"/sign-in"} class="neon-link hover:text-cyan-300 transition-colors">
                АВТОРИЗУЙТЕСЬ
              </a>
              ЧТОБЫ ОСТАВИТЬ КОММЕНТАРИЙ
            </p>
          </div>
        <% end %>

        <div class="cyber-comments-container space-y-6">
          <%= for comment <- @comments do %>
            <div class="cyber-comment relative group" id={"comment-#{comment.id}"}>
              <div class="absolute top-0 left-0 w-3 h-3 border-l border-t border-cyan-500 opacity-30 group-hover:opacity-70 transition-opacity">
              </div>

              <%= if comment.is_hidden do %>
                <div class="relative group" id={"reply-#{comment.id}"}>
                  <div class="absolute top-0 left-0 w-2 h-2 border-l border-t border-red-500 group-hover:opacity-0 transition-opacity">
                  </div>

                  <div class="cyber-reply-card p-4 rounded-lg border border-red-500/30 bg-gradient-to-br from-gray-900/80 to-gray-800/80 backdrop-blur-sm group-hover:border-red-400/50 transition-all duration-300 relative overflow-hidden">
                    <div class="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0MCIgaGVpZ2h0PSI0MCI+CiAgPHJlY3Qgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBmaWxsPSIjMDAwIiBmaWxsLW9wYWNpdHk9IjAuMSIvPgogIDxwYXRoIGQ9Ik0wIDAgTDIwIDIwIE0xMCAwIEwzMCAyMCBNMjAgMCBMNDAgMjAgTTMwIDAgTDQwIDEwIE0wIDIwIEwyMCA0MCBNMCAzMCBMMTAgNDAgTTIwIDIwIEwwIDQwIE0zMCA0MCBMNDAgMzAgTTQwIDIwIEwyMCA0MCIgc3Ryb2tlPSIjZmYwMDMzIiBzdHJva2Utb3BhY2l0eT0iMC4xIiBzdHJva2Utd2lkdGg9IjEiLz4KPC9zdmc+')] opacity-40 mix-blend-overlay">
                    </div>

                    <div class="absolute top-0 left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-red-500 to-transparent animate-scanline">
                    </div>

                    <div class="flex flex-col items-center justify-center text-center">
                      <div class="relative mb-3">
                        <svg
                          xmlns="http://www.w3.org/2000/svg"
                          class="h-8 w-8 text-red-500"
                          viewBox="0 0 20 20"
                          fill="currentColor"
                        >
                          <path
                            fill-rule="evenodd"
                            d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z"
                            clip-rule="evenodd"
                          />
                        </svg>
                        <div class="absolute inset-0 rounded-full bg-red-500 animate-ping opacity-20 -z-10">
                        </div>
                      </div>

                      <div class="text-red-400 font-bold text-sm mb-1 tracking-wider neon-text-red">
                        [ СИСТЕМНОЕ УВЕДОМЛЕНИЕ: КОД 0x7E ]
                      </div>

                      <div class="text-gray-400 text-xm">
                        <div class="mb-1">Комментарий был скрыт модератором или владельцем</div>
                        <div class="text-gray-500 text-xxs italic mt-2">
                          "Доступ к этому сегменту данных ограничен согласно протоколу кибербезопасности 451.
                          Содержимое может нарушать корпоративные стандарты нейросетевой этики."
                        </div>
                      </div>

                      <div class="mt-3 text-xxs font-mono text-gray-600 flex gap-2">
                        <span class="animate-pulse">%%ERROR%%</span>
                        <span>ACCESS_DENIED</span>
                        <span class="text-red-500">0x7E</span>
                      </div>
                    </div>
                  </div>
                </div>
              <% else %>
                <div class="cyber-comment-card p-6 rounded-xl border border-cyan-500/20 bg-gradient-to-br from-gray-900/50 to-gray-800/50 backdrop-blur-sm group-hover:border-cyan-400 transition-all duration-300">
                  <div class="flex justify-between items-start mb-4">
                    <div class="flex items-start">
                      <%= if comment.author.profile_image do %>
                        <img
                          src={comment.author.profile_image}
                          class="w-10 h-10 rounded-full bg-gradient-to-r from-cyan-900/30 to-purple-900/30 object-cover border border-cyan-500/30 mr-4"
                        />
                      <% else %>
                        <div class="w-10 h-10 rounded-full bg-gradient-to-r from-cyan-900/30 to-purple-900/30 flex items-center justify-center text-cyan-400 font-bold mr-4 border border-cyan-500/30">
                          {String.at(comment.author.username, 0) |> String.upcase()}
                        </div>
                      <% end %>

                      <div>
                        <div class="font-bold text-cyan-300">{comment.author.username}</div>
                        <div class="text-xs text-cyan-500">
                          {Timex.format!(comment.inserted_at, "{D} {Mshort} {YYYY} в {h24}:{m}")}
                        </div>
                      </div>
                    </div>

                    <div class="flex gap-2">
                      <%= if can_edit_comment?(@current_user, comment) do %>
                        <button
                          phx-click="edit_comment"
                          phx-value-id={comment.id}
                          phx-target={@myself}
                          class="cyber-icon-btn text-cyan-400 hover:text-cyan-300"
                          title="Редактировать"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="h-4 w-4"
                            viewBox="0 0 20 20"
                            fill="currentColor"
                          >
                            <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
                          </svg>
                        </button>
                      <% end %>
                      <%= if can_delete_comment?(@current_user, comment) do %>
                        <button
                          phx-click="delete_comment"
                          phx-value-id={comment.id}
                          phx-target={@myself}
                          class="cyber-icon-btn text-red-400 hover:text-red-300"
                          title="Удалить"
                        >
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="h-4 w-4"
                            viewBox="0 0 20 20"
                            fill="currentColor"
                          >
                            <path
                              fill-rule="evenodd"
                              d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </button>
                      <% end %>
                    </div>
                  </div>

                  <%= if @editing_comment_id == comment.id do %>
                    <div class="ml-13 mb-4">
                      <.form
                        for={@edit_changeset}
                        as={:form}
                        phx-submit="save_edit"
                        phx-change="validate_edit"
                        phx-target={@myself}
                      >
                        <div class="relative">
                          <.input
                            field={@edit_changeset[:content]}
                            type="textarea"
                            class="w-full bg-gray-800/50 border border-cyan-500/30 rounded-lg py-3 px-4 text-cyan-200 focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent h-24 font-mono"
                            placeholder="Редактировать комментарий..."
                            rows="3"
                          />
                          <div class="flex gap-2 mt-2 justify-end">
                            <button
                              type="submit"
                              class="cyber-button px-4 py-2 rounded-lg border border-cyan-500 text-cyan-400 hover:bg-cyan-500/10 text-sm"
                            >
                              СОХРАНИТЬ
                            </button>
                            <button
                              type="button"
                              phx-click="cancel_edit"
                              phx-target={@myself}
                              class="cyber-button px-4 py-2 rounded-lg border border-gray-500 text-gray-400 hover:bg-gray-500/10 text-sm"
                            >
                              ОТМЕНА
                            </button>
                          </div>
                        </div>
                      </.form>
                    </div>
                  <% else %>
                    <div class="text-gray-200 ml-13 font-light">
                      {comment.content}
                    </div>
                  <% end %>

                  <div class="ml-13 mt-3">
                    <%= if @current_user do %>
                      <button
                        phx-click="reply_to_comment"
                        phx-value-id={comment.id}
                        phx-target={@myself}
                        class="cyber-link text-xs text-cyan-500 hover:text-cyan-300"
                      >
                        ОТВЕТИТЬ
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <%= if @replying_to_comment_id == comment.id do %>
                <div class="cyber-reply-form ml-13 mt-4 border-l-2 border-cyan-500/30 pl-4">
                  <.form
                    for={@reply_changeset}
                    as={:form}
                    phx-submit="submit_reply"
                    phx-change="validate_reply"
                    phx-target={@myself}
                    class="mb-4"
                  >
                    <div class="relative">
                      <div class="cyber-input-container">
                        <.input
                          field={@reply_changeset[:content]}
                          type="textarea"
                          class="w-full bg-gray-800/50 border border-cyan-500/30 rounded-lg py-3 px-4 pl-10 text-cyan-200 focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent h-24 font-mono text-sm"
                          placeholder="Ваш ответ..."
                          rows="2"
                        />
                        <div class="absolute top-3 left-3 text-cyan-500">
                          <svg
                            xmlns="http://www.w3.org/2000/svg"
                            class="h-4 w-4"
                            viewBox="0 0 20 20"
                            fill="currentColor"
                          >
                            <path
                              fill-rule="evenodd"
                              d="M18 5v8a2 2 0 01-2 2h-5l-5 4v-4H4a2 2 0 01-2-2V5a2 2 0 012-2h12a2 2 0 012 2zM7 8H5v2h2V8zm2 0h2v2H9V8zm6 0h-2v2h2V8z"
                              clip-rule="evenodd"
                            />
                          </svg>
                        </div>
                      </div>

                      <div class="flex gap-2 mt-2 justify-end">
                        <button
                          type="submit"
                          class="cyber-button px-4 py-2 rounded-lg border border-cyan-500 text-cyan-400 hover:bg-cyan-500/10 text-sm"
                        >
                          ОТПРАВИТЬ ОТВЕТ
                        </button>
                        <button
                          type="button"
                          phx-click="cancel_reply"
                          phx-target={@myself}
                          class="cyber-button px-4 py-2 rounded-lg border border-gray-500 text-gray-400 hover:bg-gray-500/10 text-sm"
                        >
                          ОТМЕНА
                        </button>
                      </div>
                    </div>
                  </.form>
                </div>
              <% end %>

              <%= if Map.has_key?(comment, :replies) && is_list(comment.replies) && length(comment.replies) > 0 do %>
                <div class="cyber-replies-container ml-13 mt-4 border-l-2 border-cyan-500/30 pl-4 space-y-4">
                  <%= for reply <- Enum.sort_by(comment.replies, & &1.inserted_at, :asc) do %>
                    <%= if reply.is_hidden do %>
                      <div class="relative group" id={"reply-#{reply.id}"}>
                        <div class="absolute top-0 left-0 w-2 h-2 border-l border-t border-red-500 group-hover:opacity-0 transition-opacity">
                        </div>

                        <div class="cyber-reply-card p-4 rounded-lg border border-red-500/30 bg-gradient-to-br from-gray-900/80 to-gray-800/80 backdrop-blur-sm group-hover:border-red-400/50 transition-all duration-300 relative overflow-hidden">
                          <div class="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0MCIgaGVpZ2h0PSI0MCI+CiAgPHJlY3Qgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBmaWxsPSIjMDAwIiBmaWxsLW9wYWNpdHk9IjAuMSIvPgogIDxwYXRoIGQ9Ik0wIDAgTDIwIDIwIE0xMCAwIEwzMCAyMCBNMjAgMCBMNDAgMjAgTTMwIDAgTDQwIDEwIE0wIDIwIEwyMCA0MCBNMCAzMCBMMTAgNDAgTTIwIDIwIEwwIDQwIE0zMCA0MCBMNDAgMzAgTTQwIDIwIEwyMCA0MCIgc3Ryb2tlPSIjZmYwMDMzIiBzdHJva2Utb3BhY2l0eT0iMC4xIiBzdHJva2Utd2lkdGg9IjEiLz4KPC9zdmc+')] opacity-40 mix-blend-overlay">
                          </div>

                          <div class="absolute top-0 left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-red-500 to-transparent animate-scanline">
                          </div>

                          <div class="flex flex-col items-center justify-center text-center">
                            <div class="relative mb-3">
                              <svg
                                xmlns="http://www.w3.org/2000/svg"
                                class="h-8 w-8 text-red-500"
                                viewBox="0 0 20 20"
                                fill="currentColor"
                              >
                                <path
                                  fill-rule="evenodd"
                                  d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z"
                                  clip-rule="evenodd"
                                />
                              </svg>
                              <div class="absolute inset-0 rounded-full bg-red-500 animate-ping opacity-20 -z-10">
                              </div>
                            </div>

                            <div class="text-red-400 font-bold text-sm mb-1 tracking-wider neon-text-red">
                              [ СИСТЕМНОЕ УВЕДОМЛЕНИЕ: КОД 0x7E ]
                            </div>

                            <div class="text-gray-400 text-xm">
                              <div class="mb-1">Комментарий был скрыт модератором или владельцем</div>
                              <div class="text-gray-500 text-xxs italic mt-2">
                                "Доступ к этому сегменту данных ограничен согласно протоколу кибербезопасности 451.
                                Содержимое может нарушать корпоративные стандарты нейросетевой этики."
                              </div>
                            </div>

                            <div class="mt-3 text-xxs font-mono text-gray-600 flex gap-2">
                              <span class="animate-pulse">%%ERROR%%</span>
                              <span>ACCESS_DENIED</span>
                              <span class="text-red-500">0x7E</span>
                            </div>
                          </div>
                        </div>
                      </div>
                    <% else %>
                      <div class="cyber-reply relative group" id={"reply-#{reply.id}"}>
                        <div class="absolute top-0 left-0 w-2 h-2 border-l border-t border-purple-500 group-hover:opacity-70 transition-opacity">
                        </div>

                        <div class="cyber-reply-card p-4 rounded-lg border border-purple-500/20 bg-gradient-to-br from-gray-900/40 to-gray-800/40 backdrop-blur-sm group-hover:border-purple-400 transition-all duration-300">
                          <div class="flex justify-between items-start mb-2">
                            <div class="flex items-start">
                              <%= if reply.author.profile_image do %>
                                <img
                                  src={reply.author.profile_image}
                                  class="w-8 h-8 rounded-full bg-gradient-to-r from-purple-900/30 to-pink-900/30 object-cover border border-purple-500/30 mr-3"
                                />
                              <% else %>
                                <div class="w-8 h-8 rounded-full bg-gradient-to-r from-purple-900/30 to-pink-900/30 flex items-center justify-center text-purple-400 font-bold mr-3 border border-purple-500/30">
                                  {String.at(reply.author.username, 0) |> String.upcase()}
                                </div>
                              <% end %>

                              <div>
                                <div class="font-bold text-purple-300 text-sm">
                                  {reply.author.username}
                                </div>
                                <div class="text-xs text-purple-500">
                                  {Timex.format!(reply.inserted_at, "{D} {Mshort} {YYYY} в {h24}:{m}")}
                                </div>
                              </div>
                            </div>

                            <div class="flex gap-2">
                              <%= if can_edit_comment?(@current_user, reply) do %>
                                <button
                                  phx-click="edit_comment"
                                  phx-value-id={reply.id}
                                  phx-target={@myself}
                                  class="cyber-icon-btn text-purple-400 hover:text-purple-300"
                                  title="Редактировать"
                                >
                                  <svg
                                    xmlns="http://www.w3.org/2000/svg"
                                    class="h-3 w-3"
                                    viewBox="0 0 20 20"
                                    fill="currentColor"
                                  >
                                    <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
                                  </svg>
                                </button>
                              <% end %>
                              <%= if can_delete_comment?(@current_user, reply) do %>
                                <button
                                  phx-click="delete_comment"
                                  phx-value-id={reply.id}
                                  phx-target={@myself}
                                  class="cyber-icon-btn text-red-400 hover:text-red-300"
                                  title="Удалить"
                                >
                                  <svg
                                    xmlns="http://www.w3.org/2000/svg"
                                    class="h-3 w-3"
                                    viewBox="0 0 20 20"
                                    fill="currentColor"
                                  >
                                    <path
                                      fill-rule="evenodd"
                                      d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z"
                                      clip-rule="evenodd"
                                    />
                                  </svg>
                                </button>
                              <% end %>
                            </div>
                          </div>

                          <%= if @editing_comment_id == reply.id do %>
                            <div class="ml-11 mb-2">
                              <.form
                                for={@edit_changeset}
                                as={:form}
                                phx-submit="save_edit"
                                phx-change="validate_edit"
                                phx-target={@myself}
                              >
                                <div class="relative">
                                  <.input
                                    field={@edit_changeset[:content]}
                                    type="textarea"
                                    class="w-full bg-gray-800/50 border border-purple-500/30 rounded-lg py-2 px-3 text-cyan-200 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent h-20 font-mono text-sm"
                                    placeholder="Редактировать ответ..."
                                    rows="2"
                                  />
                                  <div class="flex gap-2 mt-2 justify-end">
                                    <button
                                      type="submit"
                                      class="cyber-button px-3 py-1 rounded-lg border border-purple-500 text-purple-400 hover:bg-purple-500/10 text-xs"
                                    >
                                      СОХРАНИТЬ
                                    </button>
                                    <button
                                      type="button"
                                      phx-click="cancel_edit"
                                      phx-target={@myself}
                                      class="cyber-button px-3 py-1 rounded-lg border border-gray-500 text-gray-400 hover:bg-gray-500/10 text-xs"
                                    >
                                      ОТМЕНА
                                    </button>
                                  </div>
                                </div>
                              </.form>
                            </div>
                          <% else %>
                            <div class="text-gray-300 ml-11 text-sm">{reply.content}</div>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
