import {
  BadRequestException,
  Body,
  Controller,
  HttpCode,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBadRequestResponse,
  ApiInternalServerErrorResponse,
  ApiOkResponse,
  ApiOperation,
  ApiServiceUnavailableResponse,
  ApiTags,
  ApiTooManyRequestsResponse,
} from '@nestjs/swagger';
import { AppService } from './app.service';
import { StudyRequestDto } from './dto/study-request.dto';
import { StudyResponseDto } from './dto/study-response.dto';
import { RateLimitGuard } from './rate-limit.guard';

@ApiTags('Study')
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Post('study')
  @UseGuards(RateLimitGuard)
  @HttpCode(200)
  @ApiOperation({
    summary: 'Envia uma pergunta para o professor virtual Gemini',
  })
  @ApiOkResponse({
    description:
      'Resposta gerada pelo Gemini no formato pedagógico solicitado.',
    type: StudyResponseDto,
  })
  @ApiBadRequestResponse({ description: 'O campo question não foi enviado.' })
  @ApiTooManyRequestsResponse({
    description:
      'Limite de 5 requisições por minuto atingido para esta origem.',
  })
  @ApiServiceUnavailableResponse({
    description: 'Gemini temporariamente sobrecarregado.',
  })
  @ApiInternalServerErrorResponse({
    description: 'Falha interna ao processar a solicitação no Gemini.',
  })
  async askProfessor(@Body() payload: StudyRequestDto) {
    const question = payload?.question?.trim();

    if (!question) {
      throw new BadRequestException('O campo "question" é obrigatório.');
    }

    return this.appService.requestProfessorResponse(question);
  }
}
