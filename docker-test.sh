#!/bin/bash
# Helper script to build and run tests in Docker with multiple Emacs versions

set -e

# Parse Emacs version argument (default: emacs-29)
EMACS_VERSION=${1:-emacs-29}
TEST_TYPE=${2:-standard}

# Validate Emacs version
if [[ "$EMACS_VERSION" != "emacs-29" && "$EMACS_VERSION" != "emacs-30" ]]; then
    echo "Error: Invalid Emacs version '$EMACS_VERSION'"
    echo "Usage: $0 [emacs-29|emacs-30] [test-type]"
    exit 1
fi

# Convert emacs-29 -> emacs29 for filenames
DOCKERFILE_SUFFIX=$(echo "$EMACS_VERSION" | tr -d '-')
IMAGE_NAME="tuareg-test-${EMACS_VERSION}"
DOCKERFILE="Dockerfile.${DOCKERFILE_SUFFIX}"

# Build the Docker image
echo "Building Docker image for ${EMACS_VERSION}..."
docker build -f ${DOCKERFILE} -t ${IMAGE_NAME} .

# Function to run tests
run_tests() {
    local test_type=$1
    echo ""
    echo "=========================================="
    echo "Running $test_type tests on ${EMACS_VERSION}..."
    echo "=========================================="

    case $test_type in
        "standard")
            docker run --rm $IMAGE_NAME make check
            ;;
        "tree-sitter")
            docker run --rm $IMAGE_NAME \
                emacs -batch -Q -L . -l tuareg-tree-sitter-tests \
                -f ert-run-tests-batch-and-exit
            ;;
        "tree-sitter-with-install")
            docker run --rm $IMAGE_NAME bash -c "
                echo 'Installing tree-sitter grammars...' && \
                emacs -batch -Q -L . \
                    --eval '(progn (require (quote tuareg-treesitter-install)) (tuareg-treesitter--install-grammars-noninteractive))' && \
                echo 'Running tree-sitter tests...' && \
                emacs -batch -Q -L . -l tuareg-tree-sitter-tests \
                    -f ert-run-tests-batch-and-exit
            "
            ;;
        "menhir")
            docker run --rm $IMAGE_NAME \
                emacs -batch -Q -L . -l tuareg-tree-sitter-tests \
                --eval '(ert-run-tests-batch-and-exit "tuareg-menhir-treesitter")'
            ;;
        "ocamllex")
            docker run --rm $IMAGE_NAME \
                emacs -batch -Q -L . -l tuareg-tree-sitter-tests \
                --eval '(ert-run-tests-batch-and-exit "tuareg-ocamllex-treesitter")'
            ;;
        "all")
            run_tests "standard"
            run_tests "tree-sitter"
            ;;
        "shell")
            docker run --rm -it $IMAGE_NAME bash
            ;;
        *)
            echo "Unknown test type: $test_type"
            echo "Usage: $0 [emacs-29|emacs-30] [standard|tree-sitter|tree-sitter-with-install|menhir|ocamllex|all|shell]"
            exit 1
            ;;
    esac
}

run_tests $TEST_TYPE

echo ""
echo "Tests completed!"
