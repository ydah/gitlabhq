# frozen_string_literal: true

# TOOD: https://gitlab.com/gitlab-org/gitlab/-/issues/425379
# WARNING: This module has been deprecated.
# The module solely exists because ExtractsPath depends on this module (ExtractsPath is the only user.)
# ExtractsRef::RefExtractor class is a refactored version of this module and provides
# the same functionalities. You should use the class instead.
#
# Module providing methods for dealing with separating a tree-ish string and a
# file path string when combined in a request parameter
# Can be extended for different types of repository object, e.g. Project or Snippet
module ExtractsRef
  InvalidPathError = ExtractsRef::RefExtractor::InvalidPathError
  BRANCH_REF_TYPE = ExtractsRef::RefExtractor::BRANCH_REF_TYPE
  TAG_REF_TYPE = ExtractsRef::RefExtractor::TAG_REF_TYPE
  REF_TYPES = ExtractsRef::RefExtractor::REF_TYPES

  def self.ref_type(type)
    ExtractsRef::RefExtractor.ref_type(type)
  end

  # Given a string containing both a Git tree-ish, such as a branch or tag, and
  # a filesystem path joined by forward slashes, attempts to separate the two.
  #
  # Expects a repository_container method that returns the active repository object. This is
  # used to check the input against a list of valid repository refs.
  #
  # Examples
  #
  #   # No repository_container available
  #   extract_ref('master')
  #   # => ['', '']
  #
  #   extract_ref('master')
  #   # => ['master', '']
  #
  #   extract_ref("f4b14494ef6abf3d144c28e4af0c20143383e062/CHANGELOG")
  #   # => ['f4b14494ef6abf3d144c28e4af0c20143383e062', 'CHANGELOG']
  #
  #   extract_ref("v2.0.0/README.md")
  #   # => ['v2.0.0', 'README.md']
  #
  #   extract_ref('master/app/models/project.rb')
  #   # => ['master', 'app/models/project.rb']
  #
  #   extract_ref('issues/1234/app/models/project.rb')
  #   # => ['issues/1234', 'app/models/project.rb']
  #
  #   # Given an invalid branch, we fall back to just splitting on the first slash
  #   extract_ref('non/existent/branch/README.md')
  #   # => ['non', 'existent/branch/README.md']
  #
  # Returns an Array where the first value is the tree-ish and the second is the
  # path
  def extract_ref(id)
    pair = extract_raw_ref(id)

    [
      pair[0].strip,
      pair[1].delete_prefix('/').delete_suffix('/')
    ]
  end

  # Assigns common instance variables for views working with Git tree-ish objects
  #
  # Assignments are:
  #
  # - @id     - A string representing the joined ref and path
  # - @ref    - A string representing the ref (e.g., the branch, tag, or commit SHA)
  # - @path   - A string representing the filesystem path
  # - @commit - A Commit representing the commit from the given ref
  #
  # If the :id parameter appears to be requesting a specific response format,
  # that will be handled as well.
  # rubocop:disable Gitlab/ModuleWithInstanceVariables
  def assign_ref_vars
    @id, @ref, @path = extract_ref_path
    @repo = repository_container.repository
    raise InvalidPathError if @ref.match?(/\s/)

    return unless @ref.present?

    @commit = if ref_type
                @fully_qualified_ref = ExtractsRef::RefExtractor.qualify_ref(@ref, ref_type)
                @repo.commit(@fully_qualified_ref)
              else
                @repo.commit(@ref)
              end
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables

  def tree
    @tree ||= @repo.tree(@commit.id, @path) # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end

  def extract_ref_path
    id = get_id
    ref, path = extract_ref(id)

    [id, ref, path]
  end

  def ref_type
    ExtractsRef.ref_type(params[:ref_type])
  end

  private

  def extract_raw_ref(id)
    return ['', ''] unless repository_container

    sha_regex =
      if Feature.enabled?(:ref_extract_sha256, Feature.current_request)
        /^(\h{40}\h{24}?)(.*)/
      else
        /^(\h{40})(.+)/
      end

    # If the ref appears to be a SHA, we're done, just split the string
    return $~.captures if id =~ sha_regex

    # No slash means we must have a ref and no path
    return [id, ''] unless id.include?('/')

    # Otherwise, attempt to detect the ref using a list of the
    # repository_container's branches and tags

    # Append a trailing slash if we only get a ref and no file path
    id = [id, '/'].join unless id.ends_with?('/')
    first_path_segment, rest = id.split('/', 2)

    return [first_path_segment, rest] if use_first_path_segment?(first_path_segment)

    valid_refs = ref_names.select { |v| id.start_with?("#{v}/") }

    # No exact ref match, so just try our best
    return id.match(%r{([^/]+)(.*)}).captures if valid_refs.empty?

    # There is a distinct possibility that multiple refs prefix the ID.
    # Use the longest match to maximize the chance that we have the
    # right ref.
    best_match = valid_refs.max_by(&:length)

    # Partition the string into the ref and the path, ignoring the empty first value
    id.partition(best_match)[1..]
  end

  def use_first_path_segment?(ref)
    return false unless repository_container
    return false if repository_container.repository.has_ambiguous_refs?

    repository_container.repository.branch_names_include?(ref) ||
      repository_container.repository.tag_names_include?(ref)
  end

  # overridden in subclasses, do not remove
  def get_id
    allowed_params = params.permit(:id, :ref, :path)

    id = [allowed_params[:id] || allowed_params[:ref]]
    id << "/" + allowed_params[:path] unless allowed_params[:path].blank?
    id.join
  end

  def ref_names
    return [] unless repository_container

    @ref_names ||= repository_container.repository.ref_names # rubocop:disable Gitlab/ModuleWithInstanceVariables
  end

  def repository_container
    raise NotImplementedError
  end

  # deprecated in favor of ExtractsRef::RequestedRef
  def ambiguous_ref?(project, ref)
    return false unless ref
    return true if project.repository.ambiguous_ref?(ref)
    return false unless ref.starts_with?(%r{(refs|heads|tags)/})

    unprefixed_ref = ref.sub(%r{^(refs/)?(heads|tags)/}, '')
    project.repository.commit(unprefixed_ref).present?
  end
end
