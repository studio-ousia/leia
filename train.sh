#!/bin/bash

if [ `nvidia-smi | grep "V100" | wc -l` -eq 0 ]
then
    echo "Using BF16 & flash attention 2"
    ACCELERATE_ARGS="--mixed_precision bf16"
    ARGS="${ARGS} --bf16 true --use_flash_attention_2"
else
    ACCELERATE_ARGS="--mixed_precision fp16"
    ARGS="${ARGS} --fp16 true"
fi
 
if [[ -z ${RUN_NAME} ]]; then
    echo "RUN_NAME is not set"
    exit 1
fi
if [[ -z ${MODEL_NAME_OR_PATH} ]]; then
    echo "MODEL_NAME_OR_PATH is not set"
    exit 1
fi

DIR_NAME_SUFFIX=$(echo ${MODEL_NAME_OR_PATH} | cut -d "/" -f 2)

if [[ -z ${ENTITY_EMBEDDING_DIR} ]]; then
    ENTITY_EMBEDDING_DIR="data/entity_emb/en_${DIR_NAME_SUFFIX}"
fi
if [[ -z ${WIKIPEDIA_DATASET_DIR} ]]; then
    if [[ -z ${LANGUAGE} ]]; then
        echo "LANGUAGE is not set"
        exit 1
    fi
    WIKIPEDIA_DATASET_DIR="data/wikipedia/${LANGUAGE}_${DIR_NAME_SUFFIX}"
fi

if [[ ! -z ${EVAL_TASKS} ]]; then
    ARGS="${ARGS} --eval_tasks ${EVAL_TASKS}"
fi
if [[ ! -z ${NUM_TRAIN_WIKIPEDIA_SAMPLES} ]]; then
    ARGS="${ARGS} --num_train_wikipedia_samples ${NUM_TRAIN_WIKIPEDIA_SAMPLES}"
fi
if [[ ! -z ${NUM_EVAL_WIKIPEDIA_SAMPLES} ]]; then
    ARGS="${ARGS} --num_eval_wikipedia_samples ${NUM_EVAL_WIKIPEDIA_SAMPLES}"
fi
if [[ ! -z ${SKIP_WIKIPEDIA_SAMPLES} ]]; then
    ARGS="${ARGS} --skip_wikipedia_samples ${SKIP_WIKIPEDIA_SAMPLES}"
fi
if [[ ! -z ${RESUME_FROM_CHECKPOINT} ]]; then
    ARGS="${ARGS} --resume_from_checkpoint ${RESUME_FROM_CHECKPOINT}"
fi

accelerate launch \
    --num_machines 1 \
    --num_processes ${NUM_PROCESSES:-`nvidia-smi --query-gpu=name --format=csv,noheader | wc -l`} \
    --dynamo_backend "no" \
    \
    --use_deepspeed \
    --zero_stage 3 \
    --zero3_init_flag false \
    --zero3_save_16bit_model true \
    \
    --gradient_accumulation_steps ${GRADIENT_ACCUMULATION_STEPS:-"32"} \
    --gradient_clipping ${GRADIENT_CLIPPING:-"1.0"} \
    \
    ${ACCELERATE_ARGS} \
    \
    train.py \
    \
    --run_name ${RUN_NAME} \
    --output_dir ${OUTPUT_DIR:-"runs/${RUN_NAME}"} \
    \
    --model_name_or_path ${MODEL_NAME_OR_PATH} \
    --entity_embedding_dir ${ENTITY_EMBEDDING_DIR} \
    --wikipedia_dataset_dir ${WIKIPEDIA_DATASET_DIR} \
    \
    --text_dataset_path ${TEXT_DATASET_PATH:-""} \
    --text_dataset_name ${TEXT_DATASET_NAME:-""} \
    --text_dataset_sampling_prob ${TEXT_DATASET_SAMPLING_PROB:-"0.0"} \
    \
    --per_device_train_batch_size ${PER_DEVICE_TRAIN_BATCH_SIZE:-"1"} \
    --per_device_eval_batch_size ${PER_DEVICE_EVAL_BATCH_SIZE:-"2"} \
    --gradient_accumulation_steps ${GRADIENT_ACCUMULATION_STEPS:-"32"} \
    --gradient_checkpointing ${GRADIENT_CHECKPOINTING:-"true"} \
    --learning_rate ${LEARNING_RATE:-"2e-5"} \
    --lr_scheduler_type ${LR_SCHEDULER_TYPE:-"constant_with_warmup"} \
    --max_steps ${MAX_STEPS:-"1000000"} \
    --warmup_steps ${WARMUP_STEPS:-"500"} \
    --weight_decay ${WEIGHT_DECAY:-"0.1"} \
    --adam_beta1 ${ADAM_BETA1:-"0.9"} \
    --adam_beta2 ${ADAM_BETA2:-"0.999"} \
    --adam_epsilon ${ADAM_EPSILON:-"1e-6"} \
    --eval_steps ${EVAL_STEPS:-"100"} \
    --evaluation_strategy "steps" \
    \
    --max_length ${MAX_LENGTH:-"2048"} \
    --max_entity_length ${MAX_ENTITY_LENGTH:-"128"} \
    --entity_vocab_size ${ENTITY_VOCAB_SIZE:-"300000"} \
    \
    --layer_index ${LAYER_INDEX:-"31"} \
    --similarity_function ${SIMILARITY_FUNCTION:-"cosine"} \
    --temperature ${TEMPERATURE:-"0.01"} \
    --use_entity_prev_token_prediction ${USE_ENTITY_PREV_TOKEN_PREDICTION:-"true"} \
    --use_entity_last_token_prediction ${USE_ENTITY_LAST_TOKEN_PREDICTION:-"true"} \
    --use_entity_decoder_activation ${USE_ENTITY_DECODER_ACTIVATION:-"false"} \
    \
    --max_eval_samples_for_tasks ${MAX_EVAL_SAMPLES_FOR_TASKS:-"3000"} \
    --use_dynamic_generation_length ${USE_DYNAMIC_GENERATION_LENGTH:-"true"} \
    \
    --train_entity_dense_only ${TRAIN_ENTITY_DENSE_ONLY:-"false"} \
    \
    --save_steps ${SAVE_STEPS:-"100"} \
    \
    --log_level "info" \
    --logging_steps "10" \
    \
    --save_strategy "no" \
    --save_steps ${SAVE_STEPS:-"500"} \
    --save_total_limit ${SAVE_TOTAL_LIMIT:-"1"} \
    \
    --seed "42" \
    --dataloader_num_workers "1" \
    --overwrite_output_dir "true" \
    --remove_unused_columns "false" \
    \
    $ARGS