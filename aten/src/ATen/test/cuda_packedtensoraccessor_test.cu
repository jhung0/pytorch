#define CATCH_CONFIG_MAIN
#include "catch_utils.hpp"

#include "ATen/ATen.h"
#include "test_seed.h"
#include "ATen/core/TensorAccessor.h"
#include "ATen/cuda/CUDAContext.h"

#include <assert.h>

using namespace at;

__global__ void test_tensor_packed_accessor_kernel(PackedTensorAccessor<float,1,RestrictPtrTraits> resa,
						   PackedTensorAccessor<float,2,RestrictPtrTraits> t1a,
						   PackedTensorAccessor<float,1,RestrictPtrTraits> t2a){
  for (int64_t i = 0; i < resa.size(0); i++) {
    float val = 0.0f;
    for (int64_t j = 0; j < t1a.size(1); j++) {
      val += t1a[i][j] * t2a[j];
    }
    resa[i] = val;
  }
}

CATCH_TEST_CASE( "test PackedTensorAccessor and Tensor.packed_accessor", "[cuda]" ) {
  manual_seed(123, at::kCPU);
  manual_seed(123, at::kCUDA);

  Tensor t1 = rand({4, 4}, CUDA(kFloat));
  Tensor t2 = rand({4}, CUDA(kFloat));
  Tensor res = empty({4}, CUDA(kFloat));

  auto t1a = t1.packed_accessor<float, 2, RestrictPtrTraits>();
  auto t2a = t2.packed_accessor<float, 1, RestrictPtrTraits>();
  auto resa = res.packed_accessor<float, 1, RestrictPtrTraits>();

  auto stream = at::cuda::getCurrentCUDAStream();
  
  test_tensor_packed_accessor_kernel<<<1, 1, 0, stream>>>(resa, t1a, t2a);
  cudaError_t err = cudaDeviceSynchronize();
  CATCH_REQUIRE(err == cudaSuccess);

  auto expected = mv(t1, t2);

  CATCH_REQUIRE(res.allclose(expected));
}
