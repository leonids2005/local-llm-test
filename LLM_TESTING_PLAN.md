# LLM Testing Plan

## Overview
This document outlines the testing strategy for evaluating self-hosted LLM models on GCP infrastructure using Terraform-managed spot instances with GPU acceleration.

## Test Infrastructure

### GPU Tiers
| Tier | GPU Model | VRAM | GCP Machine Type | Cost/Hour | Use Case |
|------|-----------|------|------------------|-----------|----------|
| 1    | T4        | 16GB | n1-standard-4    | $0.35     | Small models only |
| 2    | A100-40GB | 40GB | a2-highgpu-1g    | $3.67     | Most models (Recommended) |
| 3    | A100-80GB | 80GB | a2-ultragpu-1g   | $4.50     | Large models |
| 4    | 8x H200   | 1.1TB| Custom           | $40+      | DeepSeek only (impractical) |

### Cost Management Strategy
- Use **SPOT instances** (60-90% cheaper than on-demand)
- **Run on-demand**: Start → Test → Stop
- **Persistent disk** for models (download once, reuse forever)
- **Expected test cost**: $0.40-0.80 per model test (10-15 min runtime)

## Model Test Matrix

### Tier 1: Must Test (Core Self-Hosted)

#### 1. Qwen2.5-Coder 7B ⭐
- **GPU Required**: T4 (16GB) or higher
- **VRAM Usage**: ~7GB
- **License**: Apache 2.0
- **Strengths**: Fast, cost-effective, excellent code generation
- **Test Config**: `dev-t4.tfvars` or `dev-a100-40.tfvars`

#### 2. MiMo-V2-Flash (Xiaomi) ⭐
- **GPU Required**: A100-40GB (minimum)
- **VRAM Usage**: ~15GB active (MoE efficiency)
- **Model Size**: 309B total params, 15B active
- **Strengths**: 6× KV-cache reduction, excellent price/performance
- **Test Config**: `dev-a100-40.tfvars`
- **Note**: Very new (late 2025), verify Ollama support

#### 3. GLM-4.7 ⭐⭐
- **GPU Required**: A100-80GB (recommended)
- **VRAM Usage**: ~40GB (depends on variant)
- **Strengths**: Strong coding agents, terminal workflows, interleaved thinking
- **Optimized for**: Claude Code, Cline, Kilo Code workflows
- **Test Config**: `dev-a100-80.tfvars`

#### 4. DeepSeek-V3.2 ⭐⭐⭐
- **GPU Required**: 8× H200 (141GB each) = 1,100GB+ total
- **Cost**: $20,000+/month for dedicated infrastructure
- **Strengths**: Best OSS reasoning model, GPT-5-level performance
- **License**: MIT
- **Recommendation**: **Use via API instead** - self-hosting is cost-prohibitive
- **Test Config**: Not applicable for self-hosting

## Baseline Test Suite

### Phase 1: Infrastructure Validation
Run these tests to verify GPU setup and model loading:

```bash
# 1. Verify GPU is accessible
nvidia-smi

# 2. Check Ollama is running
docker ps | grep ollama

# 3. Verify Docker GPU access
docker exec ollama nvidia-smi

# 4. List available models
docker exec ollama ollama list
```

### Phase 2: Baseline Coding Tests (10 min per model)

#### Test 1: Simple Function (2 min)
**Prompt**:
```
Write a Python function to check if a number is prime
```

**Success Criteria**:
- ✅ Correct syntax and logic
- ✅ Response time < 30 seconds

#### Test 2: Algorithm Implementation (3 min)
**Prompt**:
```
Implement a binary search tree with insert, delete, and search operations in Python
```

**Success Criteria**:
- ✅ Complete implementation
- ✅ Proper class structure
- ✅ All methods working

#### Test 3: Code Review & Bug Fix (3 min)
**Prompt**:
```python
# Find and fix the bug in this code:
def factorial(n):
    if n == 0:
        return 0
    return n * factorial(n - 1)
```

**Success Criteria**:
- ✅ Identifies bug (base case should return 1, not 0)
- ✅ Provides corrected code
- ✅ Explains the issue

#### Test 4: Performance Benchmark (2 min)
**Purpose**: Measure inference speed

```bash
# Quick performance test
time curl http://localhost:11434/api/generate -d '{
  "model": "qwen2.5-coder:7b",
  "prompt": "Write a hello world program in Python",
  "stream": false
}'
```

**Metrics**:
- Response time
- Tokens/second
- GPU memory usage (via `nvidia-smi`)

**Success Criteria**:
- ✅ Response time < 10 seconds
- ✅ GPU utilization > 70%

### Phase 3: Results Tracking

Create a results table for each model tested:

| Model | GPU | Response Time | Code Quality (1-5) | Bug Detection | Notes |
|-------|-----|---------------|-------------------|---------------|-------|
| Qwen2.5-Coder 7B | A100-40 | | | | |
| MiMo-V2-Flash | A100-40 | | | | |
| GLM-4.7 | A100-80 | | | | |

**Code Quality Rating (1-5)**:
- 5: Perfect, production-ready code
- 4: Good code with minor improvements needed
- 3: Works but needs refactoring
- 2: Partial solution with issues
- 1: Incorrect or non-functional

**Future Test Extensions** (add as needed):
- Multi-file code generation
- API integration examples
- Test generation
- Documentation generation
- Refactoring suggestions

## Infrastructure Upgrade Procedure

### Scenario 1: T4 → A100-40GB

```bash
# 1. Stop current instance
terraform destroy -var-file=environments/dev-t4.tfvars

# 2. Deploy with A100-40GB
terraform apply -var-file=environments/dev-a100-40.tfvars

# 3. Verify GPU
gcloud compute ssh llm-server-dev --command="nvidia-smi"
```

**Downtime**: ~10 minutes (instance creation + driver installation)
**Model Data**: Preserved if using persistent disk

### Scenario 2: A100-40GB → A100-80GB

```bash
# Same as above, just change tfvars file
terraform apply -var-file=environments/dev-a100-80.tfvars
```

**Downtime**: ~10 minutes
**Cost Impact**: +$0.83/hour

## Cost Estimates

### Per-Test Costs (Assuming 15 min per model test)

| Configuration | Cost/Hour | Test Duration | Cost/Test | Models Tested | Total Cost |
|---------------|-----------|---------------|-----------|---------------|------------|
| T4 (Qwen only) | $0.35 | 15 min | $0.09 | 1 | $0.09 |
| A100-40GB (Qwen + MiMo) | $3.67 | 30 min | $1.84 | 2 | $1.84 |
| A100-80GB (All 3) | $4.50 | 45 min | $3.38 | 3 | $3.38 |

**Full test suite cost**: ~$5-6 for all models (one-time)

### Monthly Cost Scenarios

| Usage Pattern | Hours/Month | Config | Monthly Cost |
|---------------|-------------|--------|--------------|
| Light testing (2 hr/week) | 8 | A100-40GB | $29 |
| Regular development (1 hr/day) | 30 | A100-40GB | $110 |
| Heavy usage (4 hr/day) | 120 | A100-40GB | $440 |
| 24/7 development server | 730 | A100-40GB | $2,679 |

**Recommendation**: Start-stop workflow (Light-Regular usage) = $30-110/month

## Test Execution Plan

### Week 1: Infrastructure Setup & Tier 1
- [ ] Set up A100-40GB configuration
- [ ] Add persistent disk for models
- [ ] Test Qwen2.5-Coder 7B
- [ ] Test MiMo-V2-Flash
- [ ] Document baseline metrics

### Week 2: Tier 2 & Analysis
- [ ] Upgrade to A100-80GB
- [ ] Test GLM-4.7
- [ ] Run comparative analysis
- [ ] Create results report

### Week 3: Optimization
- [ ] Fine-tune startup scripts
- [ ] Optimize model loading
- [ ] Test upgrade procedures
- [ ] Document best practices

## Success Criteria

### Infrastructure
- ✅ GPU properly configured and accessible
- ✅ Models load successfully
- ✅ Ollama API responds correctly
- ✅ Upgrade process < 15 minutes

### Performance
- ✅ Inference speed meets benchmarks
- ✅ GPU utilization > 70%
- ✅ Models fit in available VRAM
- ✅ No OOM errors during testing

### Cost Management
- ✅ Actual costs within 10% of estimates
- ✅ Spot instances used successfully
- ✅ Models reused across tests
- ✅ No unexpected charges

## Next Steps

1. **Immediate**:
   - Create multi-tier tfvars files
   - Add persistent disk configuration
   - Update startup scripts

2. **Short-term**:
   - Run Phase 1 infrastructure validation
   - Test Qwen2.5-Coder on A100-40GB
   - Document initial results

3. **Long-term**:
   - Complete full test suite
   - Create automated test scripts
   - Build CI/CD for model testing
   - Consider production deployment strategy

## References

- [Ollama Model Library](https://ollama.com/library)
- [GCP GPU Pricing](https://cloud.google.com/compute/gpus-pricing)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [NVIDIA GPU Cloud](https://catalog.ngc.nvidia.com/)
