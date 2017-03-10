Code.require_file "../../../installer/test/mix_helper.exs", __DIR__

defmodule Phoenix.DupContext do
end

defmodule Mix.Tasks.Phx.Gen.ContextTest do
  use ExUnit.Case
  import MixHelper
  alias Mix.Tasks.Phx.Gen
  alias Mix.Phoenix.{Context, Schema}

  setup do
    Mix.Task.clear()
    :ok
  end

  test "new context", config do
    in_tmp_project config.test, fn ->
      schema = Schema.new("Blog.Post", "posts", [], [])
      context = Context.new("Blog", schema, [])

      assert %Context{
        pre_existing?: false,
        alias: Blog,
        base_module: Phoenix,
        basename: "blog",
        dir: "lib/phoenix/blog",
        file: "lib/phoenix/blog/blog.ex",
        module: Phoenix.Blog,
        web_module: Phoenix.Web,
        schema: %Mix.Phoenix.Schema{
          alias: Post,
          file: "lib/phoenix/blog/post.ex",
          human_plural: "Posts",
          human_singular: "Post",
          module: Phoenix.Blog.Post,
          plural: "posts",
          singular: "post"
        }} = context
    end
  end

  test "new existing context", config do
    in_tmp_project config.test, fn ->
      File.mkdir_p!("lib/phoenix/blog")
      File.write!("lib/phoenix/blog/blog.ex", """
      defmodule Phoenix.Blog do
      end
      """)

      schema = Schema.new("Blog.Post", "posts", [], [])
      assert %Context{pre_existing?: true} = Context.new("Blog", schema, [])
    end
  end

  test "invalid mix arguments", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/Expected the context, "blog", to be a valid module name/, fn ->
        Gen.Context.run(~w(blog Post posts title:string))
      end

      assert_raise Mix.Error, ~r/Expected the schema, "posts", to be a valid module name/, fn ->
        Gen.Context.run(~w(Post posts title:string))
      end

      assert_raise Mix.Error, ~r/The context and schema should have different names/, fn ->
        Gen.Context.run(~w(Blog Blog blogs))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Context.run(~w(Blog.Post posts))
      end

      assert_raise Mix.Error, ~r/Invalid arguments/, fn ->
        Gen.Context.run(~w(Blog Post))
      end
    end
  end

  test "name is already defined", config do
    in_tmp_project config.test, fn ->
      assert_raise Mix.Error, ~r/already taken/, fn ->
        Gen.Context.run ~w(DupContext Post dups)
      end
    end
  end

  test "generates context and handles existing contexts", config do
    in_tmp_project config.test, fn ->
      Gen.Context.run(~w(Blog Post posts slug:unique title:string))

      assert_file "lib/phoenix/blog/post.ex", fn file ->
        assert file =~ "field :title, :string"
      end

      assert_file "lib/phoenix/blog/blog.ex", fn file ->
        assert file =~ "def get_post!"
        assert file =~ "def list_posts"
        assert file =~ "def create_post"
        assert file =~ "def update_post"
        assert file =~ "def delete_post"
        assert file =~ "def change_post"
      end

      assert_file "test/phoenix/blog/blog_test.exs", fn file ->
        assert file =~ "use Phoenix.DataCase"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_blog_post.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:blog_posts)"
        assert file =~ "add :title, :string"
        assert file =~ "create unique_index(:blog_posts, [:slug])"
      end

      Gen.Context.run(~w(Blog Comment comments title:string))
      assert_file "lib/phoenix/blog/comment.ex", fn file ->
        assert file =~ "field :title, :string"
      end

      assert [path] = Path.wildcard("priv/repo/migrations/*_create_blog_comment.exs")
      assert_file path, fn file ->
        assert file =~ "create table(:blog_comments)"
        assert file =~ "add :title, :string"
      end

      assert_file "lib/phoenix/blog/blog.ex", fn file ->
        assert file =~ "def get_comment!"
        assert file =~ "def list_comments"
        assert file =~ "def create_comment"
        assert file =~ "def update_comment"
        assert file =~ "def delete_comment"
        assert file =~ "def change_comment"
      end
    end
  end
end
